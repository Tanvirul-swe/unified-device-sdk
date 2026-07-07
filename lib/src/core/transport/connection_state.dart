/// Represents the current state of a device connection.
///
/// This replaces the Flutter framework's ConnectionState to avoid naming
/// conflicts and provide a clearer name for device communication.
enum DeviceConnectionState {
  /// Device is disconnected.
  disconnected,

  /// Device discovery scan is active.
  scanning,

  /// Device is in the process of connecting.
  connecting,

  /// BLE link is connected.
  connected,

  /// Required GATT services have been discovered.
  servicesDiscovered,

  /// Notify characteristic subscription is active.
  notifySubscribed,

  /// BLE MTU negotiation has completed or been assumed ready.
  mtuReady,

  /// BLE transport prerequisites are satisfied.
  transportReady,

  /// UCP session bootstrap has completed.
  sessionActive,

  /// A measurement workflow is in progress.
  measurementActive,

  /// A live stream workflow is in progress.
  streamActive,

  /// A graceful session close has been requested.
  safeDisconnectPending,

  /// Device is in the process of disconnecting.
  disconnecting,

  /// Native BLE transport reported a recoverable or terminal error.
  error,

  /// Connection was lost unexpectedly.
  connectionLost,
}
