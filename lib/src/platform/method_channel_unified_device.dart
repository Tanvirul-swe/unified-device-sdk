import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'unified_device_platform.dart';

const _bleChannel = MethodChannel('unified_device_sdk/ble');
const _scanEventChannel = EventChannel('unified_device_sdk/ble/scan');
const _connectionEventChannel = EventChannel(
  'unified_device_sdk/ble/connection',
);
const _notificationEventChannel = EventChannel(
  'unified_device_sdk/ble/notification',
);

/// Method channel implementation of [UnifiedDevicePlatform].
///
/// This class handles all communication between Dart and native platform code
/// through Flutter's method channels and event channels.
///
/// ## Method Channel Contract
///
/// ### BLE Methods (`unified_device_sdk/ble`)
///
/// | Method | Arguments | Returns | Description |
/// |--------|-----------|---------|-------------|
/// | `startScan` | none | `null` | Start BLE scan |
/// | `stopScan` | none | `null` | Stop BLE scan |
/// | `connect` | `{deviceId: String}` | `null` | Connect to device |
/// | `disconnect` | none | `null` | Disconnect from device |
/// | `write` | `{data: Uint8List}` | `null` | Write bytes to device |
///
/// ### Event Channels
///
/// | Channel | Event Payload | Description |
/// |---------|--------------|-------------|
/// | `unified_device_sdk/ble/scan` | `{deviceId, name, rssi, manufacturerData?, serviceUuids?}` | Device discovered |
/// | `unified_device_sdk/ble/connection` | `{state, deviceId?, message?}` | Connection state change |
/// | `unified_device_sdk/ble/notification` | `{data: base64String|Uint8List}` or `Uint8List` | Notification data received |
class MethodChannelUnifiedDevice extends UnifiedDevicePlatform {
  StreamSubscription<dynamic>? _scanSubscription;
  StreamSubscription<dynamic>? _connectionSubscription;
  StreamSubscription<dynamic>? _notificationSubscription;

  /// Controller for discovered device events.
  /// Each event is a Map with keys: deviceId, name, rssi, manufacturerData, serviceUuids.
  final StreamController<Map<String, dynamic>> _scanResultController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Controller for connection state events.
  /// Each event is a Map with keys: state, deviceId.
  final StreamController<Map<String, dynamic>> _connectionStateController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Controller for notification data events.
  /// Each event is a Map with key: data (base64-encoded String).
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Creates a [MethodChannelUnifiedDevice] and sets up event channel listeners.
  MethodChannelUnifiedDevice() {
    _setupEventListeners();
  }

  /// The main method channel for platform queries.
  @visibleForTesting
  final methodChannel = const MethodChannel('unified_device_sdk');

  /// Stream of scan result maps from the native BLE scanner.
  ///
  /// Each event map has the following keys:
  /// - `deviceId` (String): The device identifier.
  /// - `name` (String?): The advertised device name.
  /// - `rssi` (int): Signal strength in dBm.
  /// - `manufacturerData` (String?): Base64-encoded manufacturer data.
  /// - `serviceUuids` (`List<String>?`): List of advertised service UUIDs.
  @override
  Stream<Map<String, dynamic>> get scanResults => _scanResultController.stream;

  /// Stream of connection state maps from the native BLE connection.
  ///
  /// Each event map has the following keys:
  /// - `state` (String): One of `connecting`, `connected`, `disconnecting`,
  ///   `disconnected`, `connectionLost`.
  /// - `deviceId` (String?): The device identifier.
  @override
  Stream<Map<String, dynamic>> get connectionState =>
      _connectionStateController.stream;

  /// Stream of notification data maps from the native BLE notifications.
  ///
  /// Each event map has the following keys:
  /// - `data` (String): Base64-encoded byte data.
  @override
  Stream<Map<String, dynamic>> get notificationData =>
      _notificationController.stream;

  /// Sets up event channel listeners from the native layer.
  void _setupEventListeners() {
    _scanSubscription = _scanEventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _scanResultController.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (error) {
        _scanResultController.addError(error);
      },
    );

    _connectionSubscription = _connectionEventChannel
        .receiveBroadcastStream()
        .listen(
          (event) {
            if (event is Map) {
              _connectionStateController.add(Map<String, dynamic>.from(event));
            }
          },
          onError: (error) {
            _connectionStateController.addError(error);
          },
        );

    _notificationSubscription = _notificationEventChannel
        .receiveBroadcastStream()
        .listen(
          (event) {
            if (event is Map) {
              _notificationController.add(Map<String, dynamic>.from(event));
            } else if (event is Uint8List) {
              _notificationController.add({'data': event});
            }
          },
          onError: (error) {
            _notificationController.addError(error);
          },
        );
  }

  // ---- Platform Queries ----

  @override
  Future<String?> getPlatformVersion() async {
    return await methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    final result = await methodChannel.invokeMethod<bool>(
      'isBluetoothAvailable',
    );
    return result ?? false;
  }

  @override
  Future<bool> isBluetoothEnabled() async {
    final result = await methodChannel.invokeMethod<bool>('isBluetoothEnabled');
    return result ?? false;
  }

  @override
  Future<bool> requestBluetoothPermissions() async {
    final result = await methodChannel.invokeMethod<bool>(
      'requestBluetoothPermissions',
    );
    return result ?? false;
  }

  // ---- BLE Methods ----

  /// Starts scanning for BLE devices.
  @override
  Future<void> startScan() async {
    await _bleChannel.invokeMethod('startScan');
  }

  /// Stops scanning for BLE devices.
  @override
  Future<void> stopScan() async {
    await _bleChannel.invokeMethod('stopScan');
  }

  /// Connects to a BLE device by its identifier.
  @override
  Future<void> connect(String deviceId) async {
    await _bleChannel.invokeMethod('connect', {'deviceId': deviceId});
  }

  /// Disconnects from the currently connected device.
  @override
  Future<void> disconnect() async {
    await _bleChannel.invokeMethod('disconnect');
  }

  /// Writes raw bytes to the connected device.
  ///
  /// [data] is sent as raw bytes to the native layer.
  @override
  Future<void> write(List<int> data) async {
    await _bleChannel.invokeMethod('write', {'data': Uint8List.fromList(data)});
  }

  /// Disposes all event channel subscriptions and stream controllers.
  @override
  Future<void> dispose() async {
    await _scanSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _notificationSubscription?.cancel();
    await _scanResultController.close();
    await _connectionStateController.close();
    await _notificationController.close();
  }
}
