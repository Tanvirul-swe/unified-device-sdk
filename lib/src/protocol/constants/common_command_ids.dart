/// Common command IDs shared across products.
///
/// Only commands intended to be broadly reusable live here.
/// TODO: Confirm exact command ID values with the protocol spec.
class CommonCommandIds {
  CommonCommandIds._();

  /// Ping the device to check responsiveness.
  static const int ping = 0x00;

  /// Read device information (product ID, hardware version, serial, etc.).
  static const int readDeviceInfo = 0x01;

  /// Read firmware version string.
  static const int readFirmwareVersion = 0x02;

  /// Read battery level percentage and status.
  static const int readBattery = 0x03;

  /// Set the device's real-time clock.
  static const int setTime = 0x12;

  /// Returns a human-readable name for a command ID.
  static String getCommandName(int commandId) {
    return _commandNames[commandId] ??
        'Unknown Command (0x${commandId.toRadixString(16).toUpperCase().padLeft(2, '0')})';
  }

  static const Map<int, String> _commandNames = {
    ping: 'Ping',
    readDeviceInfo: 'Read Device Info',
    readFirmwareVersion: 'Read Firmware Version',
    readBattery: 'Read Battery',
    setTime: 'Set Time',
  };
}
