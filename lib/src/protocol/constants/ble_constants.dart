/// BLE-specific constants for device communication.
class BleConstants {
  BleConstants._();

  static const String defaultDeviceName = 'Aunkur_UCP1';

  // ---- BLE Roles ----
  static const int rolePeripheral = 0;
  static const int roleCentral = 1;

  // ---- Connection Parameters ----
  /// Minimum connection interval (units of 1.25ms).
  /// TODO: Confirm with hardware team — may need tuning per product.
  static const int connectionIntervalMin = 24; // 30ms

  /// Maximum connection interval (units of 1.25ms).
  /// TODO: Confirm with hardware team — may need tuning per product.
  static const int connectionIntervalMax = 40; // 50ms

  /// Connection latency (number of connection events).
  static const int connectionLatency = 0;

  /// Supervision timeout (units of 10ms).
  /// TODO: Confirm with hardware team — may need tuning per product.
  static const int supervisionTimeout = 500; // 5000ms

  // ---- MTU ----
  /// Default BLE MTU size.
  static const int defaultMtu = 23;

  /// Preferred MTU size for data transfer.
  static const int preferredMtu = 517;

  /// Fallback MTU size when the preferred request is unavailable.
  static const int fallbackMtu = 256;

  /// Maximum supported MTU size.
  static const int maxMtu = 517;

  // ---- Advertisement ----
  /// Minimum advertisement interval (units of 0.625ms).
  static const int advertisementIntervalMin = 160; // 100ms

  /// Maximum advertisement interval (units of 0.625ms).
  static const int advertisementIntervalMax = 240; // 150ms

  /// Scan interval (units of 0.625ms).
  static const int scanInterval = 80; // 50ms

  /// Scan window (units of 0.625ms).
  static const int scanWindow = 40; // 25ms

  // ---- Timeouts ----
  static const Duration scanTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration disconnectTimeout = Duration(seconds: 3);
  static const Duration readTimeout = Duration(seconds: 5);
  static const Duration writeTimeout = Duration(seconds: 5);

  // ---- Service UUIDs ----
  /// Primary BLE service UUID for device communication.
  static const String deviceService = 'FFE0';

  // ---- Characteristic UUIDs ----
  /// Characteristic used to receive notifications/indications from the device.
  static const String notifyCharacteristic = 'FFE1';

  /// Characteristic used to send commands/data to the device.
  static const String writeCharacteristic = 'FFE2';

  // ---- Scan Settings ----
  static const int scanModeLowPower = 0;
  static const int scanModeBalanced = 1;
  static const int scanModeLowLatency = 2;
  static const int scanModeOpportunistic = 3;

  // ---- Connection Priority ----
  static const int connectionPriorityBalanced = 0;
  static const int connectionPriorityHigh = 1;
  static const int connectionPriorityLowPower = 2;
}
