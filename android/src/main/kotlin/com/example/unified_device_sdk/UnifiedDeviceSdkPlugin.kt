package com.example.unified_device_sdk

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.unified_device_sdk.ble.BleManager
import com.example.unified_device_sdk.channels.BleMethodCallHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** UnifiedDeviceSdkPlugin - Main plugin entry point for Android. */
class UnifiedDeviceSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val PERMISSION_REQUEST_CODE = 48231
    }

    private lateinit var applicationContext: Context
    private var mainChannel: MethodChannel? = null
    private var bleChannel: MethodChannel? = null
    private var scanEventChannel: EventChannel? = null
    private var connectionEventChannel: EventChannel? = null
    private var notificationEventChannel: EventChannel? = null
    private var bleManager: BleManager? = null
    private var bleMethodCallHandler: BleMethodCallHandler? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermissionResult: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        mainChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "unified_device_sdk").also {
            it.setMethodCallHandler(this)
        }

        bleChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "unified_device_sdk/ble"
        )

        scanEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "unified_device_sdk/ble/scan"
        )
        connectionEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "unified_device_sdk/ble/connection"
        )
        notificationEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "unified_device_sdk/ble/notification"
        )

        bleManager = BleManager(
            applicationContext,
            requireNotNull(scanEventChannel),
            requireNotNull(connectionEventChannel),
            requireNotNull(notificationEventChannel)
        )

        bleMethodCallHandler = BleMethodCallHandler(requireNotNull(bleManager))
        bleChannel?.setMethodCallHandler(bleMethodCallHandler)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "isBluetoothAvailable" -> {
                result.success(bleManager?.isBluetoothAvailable() == true)
            }
            "isBluetoothEnabled" -> {
                result.success(bleManager?.isBluetoothEnabled() == true)
            }
            "requestBluetoothPermissions" -> {
                requestBluetoothPermissions(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun requestBluetoothPermissions(result: Result) {
        if (hasRequiredPermissions()) {
            result.success(true)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "permission_denied",
                "Bluetooth permissions require an attached Activity",
                null
            )
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "A Bluetooth permission request is already in progress",
                null
            )
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            currentActivity,
            requiredPermissions(),
            PERMISSION_REQUEST_CODE
        )
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

    private fun hasRequiredPermissions(): Boolean {
        return requiredPermissions().all { permission ->
            ContextCompat.checkSelfPermission(applicationContext, permission) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        bleManager?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachFromActivity()
    }

    private fun detachFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
        bleManager?.setActivity(null)
        pendingPermissionResult?.error(
            "permission_denied",
            "Activity detached during permission request",
            null
        )
        pendingPermissionResult = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) {
            return false
        }

        val result = pendingPermissionResult
        if (result == null) {
            return false
        }

        pendingPermissionResult = null
        val granted = grantResults.size == requiredPermissions().size &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        result.success(granted)
        return true
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        mainChannel?.setMethodCallHandler(null)
        bleChannel?.setMethodCallHandler(null)
        scanEventChannel?.setStreamHandler(null)
        connectionEventChannel?.setStreamHandler(null)
        notificationEventChannel?.setStreamHandler(null)
        bleManager?.dispose()
        pendingPermissionResult = null
        bleMethodCallHandler = null
        bleManager = null
        notificationEventChannel = null
        connectionEventChannel = null
        scanEventChannel = null
        bleChannel = null
        mainChannel = null
    }
}
