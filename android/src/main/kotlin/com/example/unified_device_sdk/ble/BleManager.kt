package com.example.unified_device_sdk.ble

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Base64
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class BleManager(
    private val context: Context,
    scanEventChannel: EventChannel,
    connectionEventChannel: EventChannel,
    notificationEventChannel: EventChannel
) {
    private data class ConnectionIssue(
        val code: String,
        val message: String,
        val details: Map<String, Any?> = emptyMap()
    ) {
        fun asEventDetails(): Map<String, Any?> {
            return buildMap {
                put("errorCode", code)
                putAll(details)
            }
        }

        fun asMethodDetails(): Map<String, Any?> {
            return details.filterValues { it != null }
        }
    }

    companion object {
        private const val TAG = "UnifiedDeviceSdkBle"
        private val SERVICE_UUID: UUID =
            UUID.fromString("0000FFE0-0000-1000-8000-00805F9B34FB")
        private val NOTIFY_CHARACTERISTIC_UUID: UUID =
            UUID.fromString("0000FFE1-0000-1000-8000-00805F9B34FB")
        private val WRITE_CHARACTERISTIC_UUID: UUID =
            UUID.fromString("0000FFE2-0000-1000-8000-00805F9B34FB")
        private val CCCD_UUID: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

    private var activity: Activity? = null
    private var scanEventSink: EventChannel.EventSink? = null
    private var connectionEventSink: EventChannel.EventSink? = null
    private var notificationEventSink: EventChannel.EventSink? = null

    private var bluetoothGatt: BluetoothGatt? = null
    private var bleScanner: BluetoothLeScanner? = null
    private var notifyCharacteristic: BluetoothGattCharacteristic? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    private var connectedDeviceId: String? = null

    private var pendingConnectResult: MethodChannel.Result? = null
    private var pendingDisconnectResult: MethodChannel.Result? = null
    private var pendingWriteResult: MethodChannel.Result? = null
    private var lastConnectionIssue: ConnectionIssue? = null
    private var isScanning = false
    private var connectionReady = false
    private var connectionRetryCount = 0
    private val maxConnectionRetries = 2

    init {
        scanEventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    scanEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    scanEventSink = null
                }
            }
        )

        connectionEventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    connectionEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    connectionEventSink = null
                }
            }
        )

        notificationEventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    notificationEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    notificationEventSink = null
                }
            }
        )
    }

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    fun isBluetoothAvailable(): Boolean = bluetoothAdapter() != null

    fun isBluetoothEnabled(): Boolean = bluetoothAdapter()?.isEnabled == true

    fun startScan(result: MethodChannel.Result) {
        if (!ensureBluetoothAvailable(result) || !ensurePermissions(result) || !ensureBluetoothEnabled(result)) {
            return
        }

        if (isScanning) {
            result.error("scan_already_running", "BLE scan is already running", null)
            return
        }

        val scanner = bluetoothAdapter()?.bluetoothLeScanner
        if (scanner == null) {
            result.error("bluetooth_unavailable", "Bluetooth LE scanner unavailable", null)
            return
        }

        bleScanner = scanner

        val filters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(SERVICE_UUID))
                .build()
        )
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        try {
            scanner.startScan(filters, settings, scanCallback)
            isScanning = true
            Log.d(TAG, "Started BLE scan for service=$SERVICE_UUID")
            result.success(null)
        } catch (securityException: SecurityException) {
            Log.e(TAG, "Bluetooth scan permission denied", securityException)
            result.error("permission_denied", "Bluetooth scan permission denied", null)
        } catch (exception: IllegalStateException) {
            Log.e(TAG, "BLE scan failed", exception)
            result.error("scan_failed", exception.message ?: "BLE scan failed", null)
        } catch (exception: Exception) {
            Log.e(TAG, "BLE scan failed", exception)
            result.error("unknown_error", "BLE scan failed", null)
        }
    }

    fun stopScan(result: MethodChannel.Result) {
        bleScanner?.let { scanner ->
            try {
                scanner.stopScan(scanCallback)
            } catch (_: SecurityException) {
                // Ignore during shutdown; permissions may have been revoked.
            }
        }
        isScanning = false
        result.success(null)
    }

    @SuppressLint("MissingPermission")
    fun connect(deviceId: String, result: MethodChannel.Result) {
        if (!ensureBluetoothAvailable(result) || !ensurePermissions(result) || !ensureBluetoothEnabled(result)) {
            return
        }

        if (pendingConnectResult != null || pendingDisconnectResult != null) {
            result.error("operation_in_progress", "Another BLE operation is already in progress", null)
            return
        }

        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.error("bluetooth_unavailable", "Bluetooth adapter unavailable", null)
            return
        }

        val device = try {
            adapter.getRemoteDevice(deviceId)
        } catch (_: IllegalArgumentException) {
            null
        }

        if (device == null) {
            result.error("device_not_found", "Bluetooth device not found", null)
            return
        }

        pendingConnectResult = result
        connectionRetryCount = 0
        connectInternal(deviceId)
    }

    @SuppressLint("MissingPermission")
    private fun connectInternal(deviceId: String) {
        val adapter = bluetoothAdapter() ?: return
        val device = try {
            adapter.getRemoteDevice(deviceId)
        } catch (_: IllegalArgumentException) {
            null
        }

        if (device == null) {
            handleConnectionFailure("device_not_found", "Bluetooth device not found")
            return
        }

        emitConnectionState("connecting", device.address)
        stopScanIfRunning()
        closeGatt()
        connectedDeviceId = device.address
        connectionReady = false
        lastConnectionIssue = null
        Log.d(TAG, "Connecting to BLE device=${device.address} (attempt ${connectionRetryCount + 1})")

        bluetoothGatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, gattCallback)
        }
        if (bluetoothGatt == null) {
            Log.e(TAG, "Failed to initiate BLE connection for device=${device.address}")
            handleConnectionFailure(
                "connect_failed",
                "Failed to initiate BLE connection",
                mapOf("deviceId" to device.address)
            )
        }
    }

    private fun triggerConnectionRetry(logMessage: String): Boolean {
        if (pendingConnectResult != null && connectionRetryCount < maxConnectionRetries) {
            connectionRetryCount++
            Log.w(TAG, "$logMessage. Retrying ($connectionRetryCount/$maxConnectionRetries) in 500ms...")
            closeGatt()
            mainHandler.postDelayed({
                val deviceId = connectedDeviceId
                if (deviceId != null && pendingConnectResult != null) {
                    connectInternal(deviceId)
                }
            }, 500)
            return true
        }
        return false
    }

    @SuppressLint("MissingPermission")
    fun disconnect(result: MethodChannel.Result) {
        if (pendingDisconnectResult != null) {
            result.error("operation_in_progress", "Another disconnect is already in progress", null)
            return
        }

        val gatt = bluetoothGatt
        if (gatt == null) {
            val deviceId = connectedDeviceId
            cleanupConnectionState()
            lastConnectionIssue = null
            connectedDeviceId = null
            emitConnectionState("disconnected", deviceId)
            result.success(null)
            return
        }

        pendingDisconnectResult = result
        emitConnectionState("disconnecting", connectedDeviceId)
        try {
            gatt.disconnect()
        } catch (securityException: SecurityException) {
            pendingDisconnectResult = null
            Log.e(TAG, "Bluetooth disconnect permission denied", securityException)
            result.error("permission_denied", "Bluetooth connect permission denied", null)
        } catch (exception: Exception) {
            pendingDisconnectResult = null
            Log.e(TAG, "BLE disconnect failed", exception)
            result.error("disconnect_failed", "BLE disconnect failed", null)
        }
    }

    @SuppressLint("MissingPermission")
    fun write(data: ByteArray, result: MethodChannel.Result) {
        Log.d(TAG, "========== BLE WRITE REQUEST ==========")
        Log.d(TAG, "write() called")
        Log.d(TAG, "data length=${data.size}")
        Log.d(TAG, "data HEX=${data.toHexString()}")

        if (!ensureBluetoothAvailable(result) || !ensurePermissions(result) || !ensureBluetoothEnabled(result)) {
            Log.e(TAG, "write() blocked: bluetooth/permission/enabled check failed")
            Log.d(TAG, "=======================================")
            return
        }

        val gatt = bluetoothGatt
        val characteristic = writeCharacteristic

        Log.d(TAG, "bluetoothGatt exists=${gatt != null}")
        Log.d(TAG, "writeCharacteristic exists=${characteristic != null}")
        Log.d(TAG, "connectionReady=$connectionReady")
        Log.d(TAG, "connectedDeviceId=$connectedDeviceId")
        Log.d(TAG, "pendingWriteResult exists=${pendingWriteResult != null}")

        if (gatt == null) {
            Log.e(TAG, "write() failed: bluetoothGatt is null")
            Log.d(TAG, "=======================================")
            result.error(
                "not_connected",
                "BLE device is not connected",
                mapOf("deviceId" to connectedDeviceId)
            )
            return
        }

        if (!connectionReady) {
            Log.e(TAG, "write() failed: connectionReady=false")
            Log.d(TAG, "=======================================")
            result.error(
                "connection_not_ready",
                "BLE connection is not ready. Services or notifications are not configured yet.",
                mapOf("deviceId" to connectedDeviceId)
            )
            return
        }

        if (characteristic == null) {
            Log.e(TAG, "write() failed: writeCharacteristic is null")
            Log.d(TAG, "=======================================")
            result.error(
                "characteristic_not_found",
                "No writable BLE characteristic is available",
                mapOf("deviceId" to connectedDeviceId)
            )
            return
        }

        Log.d(TAG, "writeCharacteristic uuid=${characteristic.uuid}")
        Log.d(TAG, "writeCharacteristic properties=${characteristic.properties}")
        Log.d(TAG, "supports PROPERTY_WRITE=${characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0}")
        Log.d(TAG, "supports PROPERTY_WRITE_NO_RESPONSE=${characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0}")

        if (pendingWriteResult != null) {
            Log.e(TAG, "write() failed: another write already in progress")
            Log.d(TAG, "=======================================")
            result.error(
                "operation_in_progress",
                "Another write is already in progress",
                mapOf("deviceId" to connectedDeviceId)
            )
            return
        }

        val supportsWrite =
            characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0

        val supportsWriteNoResponse =
            characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0

        if (!supportsWrite && !supportsWriteNoResponse) {
            Log.e(TAG, "write() failed: characteristic does not support write")
            Log.d(TAG, "=======================================")
            result.error(
                "characteristic_not_writable",
                "Characteristic does not support write",
                mapOf(
                    "deviceId" to connectedDeviceId,
                    "characteristicUuid" to characteristic.uuid.toString(),
                    "properties" to characteristic.properties
                )
            )
            return
        }

        val writeType = if (supportsWrite) {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        }

        Log.d(
            TAG,
            "selected writeType=${
                if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) {
                    "WRITE_TYPE_DEFAULT"
                } else {
                    "WRITE_TYPE_NO_RESPONSE"
                }
            }"
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                Log.d(TAG, "Using Android 13+ writeCharacteristic API")

                val status = gatt.writeCharacteristic(characteristic, data, writeType)

                Log.d(TAG, "writeCharacteristic start status=$status (${describeGattStatus(status)})")

                if (status != BluetoothGatt.GATT_SUCCESS) {
                    Log.e(TAG, "BLE write failed to start (status=$status ${describeGattStatus(status)})")
                    Log.d(TAG, "=======================================")
                    result.error(
                        "gatt_error",
                        "BLE write failed to start (status=$status ${describeGattStatus(status)})",
                        mapOf(
                            "deviceId" to connectedDeviceId,
                            "status" to status,
                            "statusName" to describeGattStatus(status)
                        )
                    )
                    return
                }

                if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
                    Log.d(TAG, "WRITE_TYPE_NO_RESPONSE: completing result immediately")
                    Log.d(TAG, "=======================================")
                    result.success(null)
                } else {
                    Log.d(TAG, "WRITE_TYPE_DEFAULT: waiting for onCharacteristicWrite callback")
                    pendingWriteResult = result
                    Log.d(TAG, "pendingWriteResult set")
                    Log.d(TAG, "=======================================")
                }
            } else {
                Log.d(TAG, "Using legacy writeCharacteristic API")

                @Suppress("DEPRECATION")
                characteristic.writeType = writeType

                @Suppress("DEPRECATION")
                characteristic.value = data

                Log.d(TAG, "Starting legacy gatt.writeCharacteristic()")

                @Suppress("DEPRECATION")
                val started = gatt.writeCharacteristic(characteristic)

                Log.d(TAG, "legacy writeCharacteristic started=$started")

                if (!started) {
                    Log.e(TAG, "BLE write failed to start")
                    Log.d(TAG, "=======================================")
                    result.error(
                        "write_failed",
                        "BLE write failed to start",
                        mapOf("deviceId" to connectedDeviceId)
                    )
                    return
                }

                if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
                    Log.d(TAG, "WRITE_TYPE_NO_RESPONSE: completing result immediately")
                    Log.d(TAG, "=======================================")
                    result.success(null)
                } else {
                    Log.d(TAG, "WRITE_TYPE_DEFAULT: waiting for onCharacteristicWrite callback")
                    pendingWriteResult = result
                    Log.d(TAG, "pendingWriteResult set")
                    Log.d(TAG, "=======================================")
                }
            }
        } catch (securityException: SecurityException) {
            Log.e(TAG, "Bluetooth write permission denied", securityException)
            Log.d(TAG, "=======================================")
            result.error(
                "permission_denied",
                "Bluetooth connect permission denied",
                mapOf("deviceId" to connectedDeviceId)
            )
        } catch (exception: Exception) {
            Log.e(TAG, "BLE write failed", exception)
            Log.d(TAG, "=======================================")
            result.error(
                "unknown_error",
                "BLE write failed",
                mapOf(
                    "deviceId" to connectedDeviceId,
                    "error" to exception.message
                )
            )
        }
    }

    private fun ByteArray.toHexString(): String {
        return joinToString(" ") { byte ->
            "%02X".format(byte)
        }
    }

    fun dispose() {
        isScanning = false
        bleScanner?.let { scanner ->
            try {
                scanner.stopScan(scanCallback)
            } catch (_: SecurityException) {
            }
        }
        completePendingResultsOnDispose()
        closeGatt()
        scanEventSink = null
        connectionEventSink = null
        notificationEventSink = null
        activity = null
    }

    private fun ensureBluetoothAvailable(result: MethodChannel.Result): Boolean {
        if (!isBluetoothAvailable()) {
            result.error("bluetooth_unavailable", "Bluetooth adapter unavailable", null)
            return false
        }
        return true
    }

    private fun ensureBluetoothEnabled(result: MethodChannel.Result): Boolean {
        if (!isBluetoothEnabled()) {
            result.error("bluetooth_disabled", "Bluetooth is disabled", null)
            return false
        }
        return true
    }

    private fun ensurePermissions(result: MethodChannel.Result): Boolean {
        if (requiredPermissions().all { permission ->
                ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
            }
        ) {
            return true
        }

        result.error("permission_denied", "Required Bluetooth permissions are not granted", null)
        return false
    }

    private fun requiredPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun bluetoothAdapter(): BluetoothAdapter? = bluetoothManager.adapter

    private fun emitScanResult(scanResult: ScanResult) {
        val record = scanResult.scanRecord
        val serviceUuids = record?.serviceUuids?.map { it.uuid.toString() } ?: emptyList()
        val manufacturerData = record?.manufacturerSpecificData
        val manufacturerBytes =
            if (manufacturerData != null && manufacturerData.size() > 0) manufacturerData.valueAt(0) else null

        val payload = hashMapOf<String, Any?>(
            "deviceId" to scanResult.device.address,
            "name" to (scanResult.device.name ?: record?.deviceName),
            "rssi" to scanResult.rssi,
            "serviceUuids" to serviceUuids
        )

        if (manufacturerBytes != null) {
            payload["manufacturerData"] = Base64.encodeToString(manufacturerBytes, Base64.NO_WRAP)
        }

        postToMain {
            scanEventSink?.success(payload)
        }
    }

    private fun emitConnectionState(
        state: String,
        deviceId: String?,
        message: String? = null,
        details: Map<String, Any?> = emptyMap()
    ) {
        val payload = hashMapOf<String, Any?>(
            "state" to state,
            "deviceId" to deviceId
        )
        if (message != null) {
            payload["message"] = message
        }
        payload.putAll(details)
        postToMain {
            connectionEventSink?.success(payload)
        }
    }

    private fun emitNotificationData(data: ByteArray) {
        val payload = hashMapOf<String, Any?>(
            "data" to Base64.encodeToString(data, Base64.NO_WRAP)
        )
        postToMain {
            notificationEventSink?.success(payload)
        }
    }

    private fun handleConnectionFailure(code: String, message: String, details: Map<String, Any?> = emptyMap()) {
        Log.e(TAG, "Connection failure [$code]: $message details=$details")
        val issue = ConnectionIssue(code, message, details)
        lastConnectionIssue = issue
        pendingConnectResult?.error(code, message, issue.asMethodDetails().takeUnless { it.isEmpty() })
        pendingConnectResult = null
        cleanupConnectionState()
    }

    private fun handleDisconnectEvent(unexpected: Boolean, wasReady: Boolean = connectionReady) {
        val deviceId = connectedDeviceId
        val connectWasPending = pendingConnectResult != null
        val disconnectWasPending = pendingDisconnectResult != null
        val issue = lastConnectionIssue
        val state = if (unexpected && wasReady) "connectionLost" else "disconnected"
        Log.d(TAG, "BLE disconnected state=$state device=$deviceId")
        cleanupConnectionState()
        closeGatt()
        emitConnectionState(
            state,
            deviceId,
            message = issue?.message,
            details = issue?.asEventDetails() ?: emptyMap()
        )

        if (connectWasPending) {
            val connectCode = if (disconnectWasPending) "operation_cancelled" else "connect_failed"
            val connectMessage = if (disconnectWasPending) {
                "BLE connection attempt was cancelled"
            } else {
                "BLE connection closed before initialization completed"
            }
            pendingConnectResult?.error(
                connectCode,
                connectMessage,
                mapOf("deviceId" to deviceId)
            )
        }
        pendingConnectResult = null

        pendingDisconnectResult?.success(null)
        pendingDisconnectResult = null

        pendingWriteResult?.error("disconnect_failed", "Disconnected before write completed", null)
        pendingWriteResult = null
        lastConnectionIssue = null
        connectedDeviceId = null
    }

    private fun cleanupConnectionState() {
        connectionReady = false
        notifyCharacteristic = null
        writeCharacteristic = null
    }

    private fun closeGatt() {
        cleanupConnectionState()
        try {
            bluetoothGatt?.close()
        } catch (exception: Exception) {
            Log.w(TAG, "Failed to close BluetoothGatt cleanly", exception)
        }
        bluetoothGatt = null
    }

    private fun stopScanIfRunning() {
        if (!isScanning) {
            return
        }
        bleScanner?.let { scanner ->
            try {
                scanner.stopScan(scanCallback)
            } catch (securityException: SecurityException) {
                Log.w(TAG, "Failed to stop scan before connect", securityException)
            } catch (exception: Exception) {
                Log.w(TAG, "Failed to stop scan before connect", exception)
            }
        }
        isScanning = false
    }

    private fun completePendingResultsOnDispose() {
        pendingConnectResult?.error("connect_failed", "BLE manager disposed", null)
        pendingConnectResult = null
        pendingDisconnectResult?.success(null)
        pendingDisconnectResult = null
        pendingWriteResult?.error("write_failed", "BLE manager disposed", null)
        pendingWriteResult = null
    }

    @SuppressLint("MissingPermission")
    private fun configureGattServices(gatt: BluetoothGatt) {
        val service: BluetoothGattService? = gatt.getService(SERVICE_UUID)
        if (service == null) {
            handleConnectionFailure(
                "service_not_found",
                "Required service FFE0 not found",
                mapOf("deviceId" to connectedDeviceId, "serviceUuid" to SERVICE_UUID.toString())
            )
            gatt.disconnect()
            return
        }

        val notify = service.getCharacteristic(NOTIFY_CHARACTERISTIC_UUID)
        val write = service.getCharacteristic(WRITE_CHARACTERISTIC_UUID)
        if (notify == null || write == null) {
            handleConnectionFailure(
                "characteristic_not_found",
                "Required FFE1/FFE2 characteristics were not found",
                mapOf(
                    "deviceId" to connectedDeviceId,
                    "notifyCharacteristicUuid" to NOTIFY_CHARACTERISTIC_UUID.toString(),
                    "writeCharacteristicUuid" to WRITE_CHARACTERISTIC_UUID.toString()
                )
            )
            gatt.disconnect()
            return
        }

        val notificationsEnabled = gatt.setCharacteristicNotification(notify, true)
        if (!notificationsEnabled) {
            handleConnectionFailure(
                "notification_enable_failed",
                "Failed to enable notifications on FFE1",
                mapOf("deviceId" to connectedDeviceId, "characteristicUuid" to NOTIFY_CHARACTERISTIC_UUID.toString())
            )
            gatt.disconnect()
            return
        }

        val cccd = notify.getDescriptor(CCCD_UUID)
        if (cccd == null) {
            handleConnectionFailure(
                "characteristic_not_found",
                "CCCD descriptor not found for FFE1",
                mapOf("deviceId" to connectedDeviceId, "descriptorUuid" to CCCD_UUID.toString())
            )
            gatt.disconnect()
            return
        }

        notifyCharacteristic = notify
        writeCharacteristic = write

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val status = gatt.writeDescriptor(cccd, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    handleConnectionFailure(
                        "notification_enable_failed",
                        "Failed to enable notifications (status=$status ${describeGattStatus(status)})",
                        mapOf(
                            "deviceId" to connectedDeviceId,
                            "status" to status,
                            "statusName" to describeGattStatus(status)
                        )
                    )
                    gatt.disconnect()
                }
            } else {
                @Suppress("DEPRECATION")
                cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                @Suppress("DEPRECATION")
                val started = gatt.writeDescriptor(cccd)
                if (!started) {
                    handleConnectionFailure(
                        "notification_enable_failed",
                        "Failed to enable notifications",
                        mapOf("deviceId" to connectedDeviceId)
                    )
                    gatt.disconnect()
                }
            }
        } catch (securityException: SecurityException) {
            Log.e(TAG, "Bluetooth connect permission denied during notification setup", securityException)
            handleConnectionFailure("permission_denied", "Bluetooth connect permission denied")
            gatt.disconnect()
        } catch (exception: Exception) {
            Log.e(TAG, "Failed to enable notifications", exception)
            handleConnectionFailure("unknown_error", "Failed to enable notifications")
            gatt.disconnect()
        }
    }

    private fun describeGattStatus(status: Int): String {
        return when (status) {
            BluetoothGatt.GATT_SUCCESS -> "GATT_SUCCESS"
            BluetoothGatt.GATT_READ_NOT_PERMITTED -> "GATT_READ_NOT_PERMITTED"
            BluetoothGatt.GATT_WRITE_NOT_PERMITTED -> "GATT_WRITE_NOT_PERMITTED"
            BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION -> "GATT_INSUFFICIENT_AUTHENTICATION"
            BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED -> "GATT_REQUEST_NOT_SUPPORTED"
            BluetoothGatt.GATT_INSUFFICIENT_ENCRYPTION -> "GATT_INSUFFICIENT_ENCRYPTION"
            BluetoothGatt.GATT_INVALID_OFFSET -> "GATT_INVALID_OFFSET"
            BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH -> "GATT_INVALID_ATTRIBUTE_LENGTH"
            BluetoothGatt.GATT_CONNECTION_CONGESTED -> "GATT_CONNECTION_CONGESTED"
            8 -> "GATT_CONN_TIMEOUT"
            19 -> "GATT_CONN_TERMINATE_PEER_USER"
            22 -> "GATT_CONN_TERMINATE_LOCAL_HOST"
            62 -> "GATT_CONN_FAIL_ESTABLISH"
            133 -> "GATT_ERROR"
            257 -> "GATT_FAILURE"
            else -> "UNKNOWN_STATUS"
        }
    }

    private fun describeConnectionState(state: Int): String {
        return when (state) {
            BluetoothGatt.STATE_CONNECTED -> "STATE_CONNECTED"
            BluetoothGatt.STATE_CONNECTING -> "STATE_CONNECTING"
            BluetoothGatt.STATE_DISCONNECTING -> "STATE_DISCONNECTING"
            BluetoothGatt.STATE_DISCONNECTED -> "STATE_DISCONNECTED"
            else -> "STATE_UNKNOWN"
        }
    }

    private fun postToMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            emitScanResult(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach(::emitScanResult)
        }

        override fun onScanFailed(errorCode: Int) {
            isScanning = false
            Log.e(TAG, "BLE scan failed (code=$errorCode)")
            postToMain {
                scanEventSink?.error("scan_failed", "BLE scan failed (code=$errorCode)", null)
            }
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            Log.d(
                TAG,
                "onConnectionStateChange device=${gatt.device?.address} status=$status " +
                    "(${describeGattStatus(status)}) newState=$newState (${describeConnectionState(newState)})"
            )
            if (status != BluetoothGatt.GATT_SUCCESS) {
                val wasReady = connectionReady
                val unexpected = pendingDisconnectResult == null && pendingConnectResult == null
                
                if (triggerConnectionRetry("GATT connection failed with status=$status (${describeGattStatus(status)})")) {
                    return
                }

                handleConnectionFailure(
                    "gatt_error",
                    "GATT connection state error (status=$status ${describeGattStatus(status)})",
                    mapOf(
                        "deviceId" to gatt.device?.address,
                        "status" to status,
                        "statusName" to describeGattStatus(status),
                        "newState" to newState,
                        "newStateName" to describeConnectionState(newState)
                    )
                )
                if (newState != BluetoothGatt.STATE_DISCONNECTED) {
                    try {
                        gatt.disconnect()
                    } catch (e: SecurityException) {
                        Log.e(TAG, "SecurityException during disconnect", e)
                        closeGatt()
                    } catch (e: Exception) {
                        Log.e(TAG, "Exception during disconnect", e)
                        closeGatt()
                    }
                } else {
                    handleDisconnectEvent(unexpected, wasReady)
                }
                return
            }

            when (newState) {
                BluetoothGatt.STATE_CONNECTED -> {
                    connectionRetryCount = 0
                    try {
                        if (!gatt.discoverServices()) {
                            if (triggerConnectionRetry("Failed to start service discovery")) {
                                return
                            }
                            handleConnectionFailure(
                                "gatt_error",
                                "Failed to discover services",
                                mapOf(
                                    "deviceId" to gatt.device?.address,
                                    "status" to status,
                                    "statusName" to describeGattStatus(status)
                                )
                            )
                            gatt.disconnect()
                        }
                    } catch (securityException: SecurityException) {
                        Log.e(TAG, "Bluetooth connect permission denied during service discovery", securityException)
                        if (triggerConnectionRetry("Bluetooth connect permission denied during service discovery")) {
                            return
                        }
                        handleConnectionFailure("permission_denied", "Bluetooth connect permission denied")
                        gatt.disconnect()
                    } catch (exception: Exception) {
                        Log.e(TAG, "BLE service discovery failed", exception)
                        if (triggerConnectionRetry("BLE service discovery failed")) {
                            return
                        }
                        handleConnectionFailure("unknown_error", "BLE service discovery failed")
                        gatt.disconnect()
                    }
                }

                BluetoothGatt.STATE_DISCONNECTED -> {
                    handleDisconnectEvent(
                        unexpected = pendingDisconnectResult == null && pendingConnectResult == null
                    )
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            Log.d(
                TAG,
                "onServicesDiscovered device=${gatt.device?.address} status=$status (${describeGattStatus(status)})"
            )
            if (status != BluetoothGatt.GATT_SUCCESS) {
                if (triggerConnectionRetry("Service discovery failed with status=$status (${describeGattStatus(status)})")) {
                    return
                }
                handleConnectionFailure(
                    "gatt_error",
                    "BLE service discovery failed (status=$status ${describeGattStatus(status)})",
                    mapOf(
                        "deviceId" to gatt.device?.address,
                        "status" to status,
                        "statusName" to describeGattStatus(status)
                    )
                )
                gatt.disconnect()
                return
            }
            configureGattServices(gatt)
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            if (descriptor.uuid != CCCD_UUID) {
                return
            }

            if (status != BluetoothGatt.GATT_SUCCESS) {
                if (triggerConnectionRetry("Descriptor write failed with status=$status (${describeGattStatus(status)})")) {
                    return
                }
                handleConnectionFailure(
                    "notification_enable_failed",
                    "Failed to enable notifications (status=$status ${describeGattStatus(status)})",
                    mapOf(
                        "deviceId" to gatt.device?.address,
                        "status" to status,
                        "statusName" to describeGattStatus(status)
                    )
                )
                gatt.disconnect()
                return
            }

            connectionReady = true
            Log.d(TAG, "BLE connection ready device=$connectedDeviceId")

            try {
                Log.d(TAG, "Requesting MTU of 512")
                gatt.requestMtu(512)
            } catch (e: SecurityException) {
                Log.w(TAG, "Permission denied while requesting MTU", e)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to request MTU", e)
            }

            emitConnectionState("connected", connectedDeviceId)
            pendingConnectResult?.success(null)
            pendingConnectResult = null
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            Log.d(
                TAG,
                "onMtuChanged device=${gatt.device?.address} mtu=$mtu status=$status " +
                    "(${describeGattStatus(status)})"
            )
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            if (characteristic.uuid == NOTIFY_CHARACTERISTIC_UUID) {
                @Suppress("DEPRECATION")
                characteristic.value?.let(::emitNotificationData)
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            if (characteristic.uuid == NOTIFY_CHARACTERISTIC_UUID) {
                emitNotificationData(value)
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            val result = pendingWriteResult ?: return
            pendingWriteResult = null
            if (status == BluetoothGatt.GATT_SUCCESS) {
                result.success(null)
            } else {
                Log.e(TAG, "BLE write failed status=$status (${describeGattStatus(status)})")
                result.error("gatt_error", "BLE write failed (status=$status)", null)
            }
        }
    }
}
