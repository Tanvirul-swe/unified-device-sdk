/// Represents the current operational status of a device.
class DeviceStatus {
  /// The current operating mode of the device.
  final int mode;

  /// The current state of the device.
  final int state;

  /// Device uptime in seconds.
  final int uptimeSeconds;

  /// The last error code, if any.
  final int errorCode;

  /// Custom status data specific to the device type.
  final List<int> customData;

  const DeviceStatus({
    required this.mode,
    required this.state,
    required this.uptimeSeconds,
    this.errorCode = 0,
    this.customData = const [],
  });

  /// Whether the device is in an error state.
  bool get hasError => errorCode != 0;

  @override
  String toString() {
    return 'DeviceStatus(mode: $mode, state: $state, '
        'uptime: ${uptimeSeconds}s, errorCode: $errorCode)';
  }
}