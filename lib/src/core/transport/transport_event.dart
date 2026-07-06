import 'connection_state.dart';
import 'discovered_device.dart';

/// Events emitted by a device transport.
///
/// Note: Most transport events are now exposed as dedicated streams
/// on [DeviceTransport] ([discoveredDevices], [connectionState],
/// [incomingBytes]). This sealed class hierarchy is retained for
/// backward compatibility and unified event handling when needed.
sealed class TransportEvent {
  const TransportEvent();
}

/// A new device was discovered during scanning.
class DeviceDiscovered extends TransportEvent {
  final DiscoveredDevice device;
  const DeviceDiscovered(this.device);
}

/// Scan has started.
class ScanStarted extends TransportEvent {
  const ScanStarted();
}

/// Scan has stopped.
class ScanStopped extends TransportEvent {
  const ScanStopped();
}

/// Connection state has changed.
class ConnectionStateChanged extends TransportEvent {
  final DeviceConnectionState state;
  final String? deviceId;
  const ConnectionStateChanged(this.state, {this.deviceId});
}

/// Data was received from the device.
class DataReceived extends TransportEvent {
  final List<int> data;
  const DataReceived(this.data);
}

/// An error occurred on the transport.
class TransportError extends TransportEvent {
  final String message;
  final Object? error;
  const TransportError(this.message, {this.error});
}
