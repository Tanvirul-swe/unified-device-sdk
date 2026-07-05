/// Represents the current state of a device connection.
///
/// This replaces the Flutter framework's ConnectionState to avoid naming
/// conflicts and provide a clearer name for device communication.
enum DeviceConnectionState {
  /// Device is disconnected.
  disconnected,

  /// Device is in the process of connecting.
  connecting,

  /// Device is connected and ready.
  connected,

  /// Device is in the process of disconnecting.
  disconnecting,

  /// Connection was lost unexpectedly.
  connectionLost,
}