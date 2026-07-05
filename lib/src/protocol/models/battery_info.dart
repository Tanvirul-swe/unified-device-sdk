/// Information about device battery status.
class BatteryInfo {
  /// Battery level as a percentage (0-100).
  final int level;

  /// Battery voltage in millivolts, if available.
  final int voltage;

  /// Whether the device is currently charging.
  final bool isCharging;

  /// Whether the battery level is low.
  final bool isLow;

  const BatteryInfo({
    required this.level,
    this.voltage = 0,
    this.isCharging = false,
    this.isLow = false,
  });

  @override
  String toString() {
    return 'BatteryInfo(level: $level%, voltage: ${voltage}mV, '
        'charging: $isCharging, low: $isLow)';
  }
}