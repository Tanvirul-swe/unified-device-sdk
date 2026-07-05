import 'dart:async';
import 'connection_state.dart';
import 'discovered_device.dart';

/// Abstract interface for device transports (BLE, serial, etc.).
///
/// Concrete implementations handle platform-specific details like BLE scanning,
/// connecting, and data transfer. The transport layer only handles raw byte
/// I/O — all frame/protocol logic is handled at higher layers.
///
/// ## Streams
///
/// - [discoveredDevices]: emits [DiscoveredDevice] objects as they are found.
/// - [connectionState]: emits [DeviceConnectionState] changes.
/// - [incomingBytes]: emits raw byte data received from the connected device.
abstract class DeviceTransport {
  /// Stream of devices discovered during scanning.
  Stream<DiscoveredDevice> get discoveredDevices;

  /// Stream of connection state changes.
  Stream<DeviceConnectionState> get connectionState;

  /// Stream of raw bytes received from the connected device.
  Stream<List<int>> get incomingBytes;

  /// Whether the transport is currently scanning for devices.
  bool get isScanning;

  /// Whether the transport is currently connected to a device.
  bool get isConnected;

  /// The device ID of the currently connected device, if any.
  String? get connectedDeviceId;

  /// Starts scanning for nearby devices.
  Future<void> startScan();

  /// Stops scanning for devices.
  Future<void> stopScan();

  /// Connects to a discovered device.
  ///
  /// The [device] must be one previously received from [discoveredDevices].
  Future<void> connect(DiscoveredDevice device);

  /// Disconnects from the currently connected device.
  Future<void> disconnect();

  /// Writes raw bytes to the connected device.
  ///
  /// Throws [Exception] if not connected.
  Future<void> write(List<int> bytes);

  /// Releases all resources held by the transport.
  Future<void> dispose();
}