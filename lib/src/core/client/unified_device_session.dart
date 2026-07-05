import '../transport/connection_state.dart';

/// Represents an active session with a connected device.
class UnifiedDeviceSession {
  /// The ID of the connected device.
  final String deviceId;

  /// The device name, if available.
  final String? deviceName;

  /// The time when the session was established.
  final DateTime startedAt;

  /// The current connection state.
  DeviceConnectionState state;

  /// Creates a [UnifiedDeviceSession].
  UnifiedDeviceSession({
    required this.deviceId,
    this.deviceName,
    DateTime? startedAt,
    this.state = DeviceConnectionState.connected,
  }) : startedAt = startedAt ?? DateTime.now();

  /// The duration the session has been active.
  Duration get duration => DateTime.now().difference(startedAt);

  /// Whether the session is still active.
  bool get isActive =>
      state == DeviceConnectionState.connected ||
      state == DeviceConnectionState.connecting;

  @override
  String toString() {
    return 'UnifiedDeviceSession(device: $deviceId, name: $deviceName, '
        'state: $state, duration: $duration)';
  }
}