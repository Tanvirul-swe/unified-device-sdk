import Flutter
import UIKit

public class UnifiedDeviceSdkPlugin: NSObject, FlutterPlugin {
    private var bleManager: BleManager?
    private var bleMethodCallHandler: BleMethodCallHandler?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = UnifiedDeviceSdkPlugin()
        let messenger = registrar.messenger()

        let mainChannel = FlutterMethodChannel(
            name: BleConstants.mainChannelName,
            binaryMessenger: messenger
        )
        registrar.addMethodCallDelegate(instance, channel: mainChannel)

        let scanEventHandler = ScanEventHandler()
        let connectionEventHandler = ConnectionEventHandler()
        let notificationEventHandler = NotificationEventHandler()

        FlutterEventChannel(
            name: BleConstants.scanEventChannelName,
            binaryMessenger: messenger
        ).setStreamHandler(scanEventHandler)
        FlutterEventChannel(
            name: BleConstants.connectionEventChannelName,
            binaryMessenger: messenger
        ).setStreamHandler(connectionEventHandler)
        FlutterEventChannel(
            name: BleConstants.notificationEventChannelName,
            binaryMessenger: messenger
        ).setStreamHandler(notificationEventHandler)

        let bleManager = BleManager(
            scanEventHandler: scanEventHandler,
            connectionEventHandler: connectionEventHandler,
            notificationEventHandler: notificationEventHandler
        )
        instance.bleManager = bleManager

        let bleMethodCallHandler = BleMethodCallHandler(bleManager: bleManager)
        instance.bleMethodCallHandler = bleMethodCallHandler

        let bleChannel = FlutterMethodChannel(
            name: BleConstants.bleChannelName,
            binaryMessenger: messenger
        )
        registrar.addMethodCallDelegate(bleMethodCallHandler, channel: bleChannel)
    }

    deinit {
        bleManager?.dispose()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS \(UIDevice.current.systemVersion)")
        case "isBluetoothAvailable":
            result(bleManager?.isBluetoothAvailable() ?? false)
        case "isBluetoothEnabled":
            result(bleManager?.isBluetoothEnabled() ?? false)
        case "requestBluetoothPermissions":
            result(bleManager?.requestBluetoothPermissions() ?? false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
