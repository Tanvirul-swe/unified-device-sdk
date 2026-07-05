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
    companion object {
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
    private var isScanning = false
    private var connectionReady = false

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
            result.success(null)
        } catch (securityException: SecurityException) {
            result.error("permission_denied", "Bluetooth scan permission denied", null)
        } catch (exception: IllegalStateException) {
            result.error("scan_failed", exception.message ?: "BLE scan failed", null)
        } catch (_: Exception) {
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
        emitConnectionState("connecting", device.address)
        closeGatt()
        connectedDeviceId = device.address
        connectionReady = false

        bluetoothGatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, gattCallback)
        }
        if (bluetoothGatt == null) {
            pendingConnectResult = null
            result.error("connect_failed", "Failed to initiate BLE connection", null)
        }
    }

    @SuppressLint("MissingPermission")
    fun disconnect(result: MethodChannel.Result) {
        if (pendingDisconnectResult != null) {
            result.error("operation_in_progress", "Another disconnect is already in progress", null)
            return
        }

        val gatt = bluetoothGatt
        if (gatt == null) {
            cleanupConnectionState()
            emitConnectionState("disconnected", connectedDeviceId)
            result.success(null)
            return
        }

        pendingDisconnectResult = result
        emitConnectionState("disconnecting", connectedDeviceId)
        try {
            gatt.disconnect()
        } catch (securityException: SecurityException) {
            pendingDisconnectResult = null
            result.error("permission_denied", "Bluetooth connect permission denied", null)
        } catch (_: Exception) {
            pendingDisconnectResult = null
            result.error("disconnect_failed", "BLE disconnect failed", null)
        }
    }

    @SuppressLint("MissingPermission")
    fun write(data: ByteArray, result: MethodChannel.Result) {
        if (!ensureBluetoothAvailable(result) || !ensurePermissions(result) || !ensureBluetoothEnabled(result)) {
            return
        }

        val gatt = bluetoothGatt
        val characteristic = writeCharacteristic
        if (gatt == null || characteristic == null || !connectionReady) {
            result.error("characteristic_not_found", "No writable BLE characteristic is available", null)
            return
        }

        if (pendingWriteResult != null) {
            result.error("operation_in_progress", "Another write is already in progress", null)
            return
        }

        val supportsWrite =
            characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0
        val supportsWriteNoResponse =
            characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0

        if (!supportsWrite && !supportsWriteNoResponse) {
            result.error("characteristic_not_found", "Characteristic does not support write", null)
            return
        }

        val writeType = if (supportsWrite) {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val status = gatt.writeCharacteristic(characteristic, data, writeType)
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    result.error("gatt_error", "BLE write failed to start (status=$status)", null)
                    return
                }
                if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
                    result.success(null)
                } else {
                    pendingWriteResult = result
                }
            } else {
                @Suppress("DEPRECATION")
                characteristic.writeType = writeType
                @Suppress("DEPRECATION")
                characteristic.value = data
                @Suppress("DEPRECATION")
                val started = gatt.writeCharacteristic(characteristic)
                if (!started) {
                    result.error("write_failed", "BLE write failed to start", null)
                    return
                }
                if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
                    result.success(null)
                } else {
                    pendingWriteResult = result
                }
            }
        } catch (_: SecurityException) {
            result.error("permission_denied", "Bluetooth connect permission denied", null)
        } catch (_: Exception) {
            result.error("unknown_error", "BLE write failed", null)
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

    private fun emitConnectionState(state: String, deviceId: String?) {
        val payload = hashMapOf<String, Any?>(
            "state" to state,
            "deviceId" to deviceId
        )
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

    private fun handleConnectionFailure(code: String, message: String) {
        pendingConnectResult?.error(code, message, null)
        pendingConnectResult = null
        cleanupConnectionState()
        closeGatt()
    }

    private fun handleDisconnectEvent(unexpected: Boolean) {
        val state = if (unexpected && connectionReady) "connectionLost" else "disconnected"
        cleanupConnectionState()
        closeGatt()
        emitConnectionState(state, connectedDeviceId)

        pendingConnectResult?.error("connect_failed", "BLE connection failed", null)
        pendingConnectResult = null

        pendingDisconnectResult?.success(null)
        pendingDisconnectResult = null

        pendingWriteResult?.error("disconnect_failed", "Disconnected before write completed", null)
        pendingWriteResult = null
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
        } catch (_: Exception) {
        }
        bluetoothGatt = null
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
            handleConnectionFailure("service_not_found", "Required service FFE0 not found")
            gatt.disconnect()
            return
        }

        val notify = service.getCharacteristic(NOTIFY_CHARACTERISTIC_UUID)
        val write = service.getCharacteristic(WRITE_CHARACTERISTIC_UUID)
        if (notify == null || write == null) {
            handleConnectionFailure(
                "characteristic_not_found",
                "Required FFE1/FFE2 characteristics were not found"
            )
            gatt.disconnect()
            return
        }

        val notificationsEnabled = gatt.setCharacteristicNotification(notify, true)
        if (!notificationsEnabled) {
            handleConnectionFailure(
                "notification_enable_failed",
                "Failed to enable notifications on FFE1"
            )
            gatt.disconnect()
            return
        }

        val cccd = notify.getDescriptor(CCCD_UUID)
        if (cccd == null) {
            handleConnectionFailure(
                "characteristic_not_found",
                "CCCD descriptor not found for FFE1"
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
                        "Failed to enable notifications (status=$status)"
                    )
                    gatt.disconnect()
                }
            } else {
                @Suppress("DEPRECATION")
                cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                @Suppress("DEPRECATION")
                val started = gatt.writeDescriptor(cccd)
                if (!started) {
                    handleConnectionFailure("notification_enable_failed", "Failed to enable notifications")
                    gatt.disconnect()
                }
            }
        } catch (_: SecurityException) {
            handleConnectionFailure("permission_denied", "Bluetooth connect permission denied")
            gatt.disconnect()
        } catch (_: Exception) {
            handleConnectionFailure("unknown_error", "Failed to enable notifications")
            gatt.disconnect()
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
            postToMain {
                scanEventSink?.error("scan_failed", "BLE scan failed (code=$errorCode)", null)
            }
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS && newState != BluetoothGatt.STATE_CONNECTED) {
                handleConnectionFailure("gatt_error", "GATT connection state error (status=$status)")
                gatt.disconnect()
                return
            }

            when (newState) {
                BluetoothGatt.STATE_CONNECTED -> {
                    try {
                        if (status != BluetoothGatt.GATT_SUCCESS || !gatt.discoverServices()) {
                            handleConnectionFailure("gatt_error", "Failed to discover services")
                            gatt.disconnect()
                        }
                    } catch (_: SecurityException) {
                        handleConnectionFailure("permission_denied", "Bluetooth connect permission denied")
                        gatt.disconnect()
                    } catch (_: Exception) {
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
            if (status != BluetoothGatt.GATT_SUCCESS) {
                handleConnectionFailure("gatt_error", "BLE service discovery failed")
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
                handleConnectionFailure("notification_enable_failed", "Failed to enable notifications")
                gatt.disconnect()
                return
            }

            connectionReady = true
            emitConnectionState("connected", connectedDeviceId)
            pendingConnectResult?.success(null)
            pendingConnectResult = null
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
                result.error("gatt_error", "BLE write failed (status=$status)", null)
            }
        }
    }
}
