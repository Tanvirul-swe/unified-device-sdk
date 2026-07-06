/// Frozen error code registry for the Unified Device SDK.
///
/// All error codes in this file are frozen for production. Do not modify
/// existing codes — only append new ones as the protocol evolves.
///
/// ## Code Ranges
///
/// | Range       | Category         |
/// |-------------|------------------|
/// | 0x0001-0x00FF | Transport errors |
/// | 0x0101-0x01FF | Protocol errors  |
/// | 0x0201-0x02FF | Session errors   |
/// | 0x0301-0x03FF | Command errors   |
/// | 0x0401-0x04FF | Device errors    |
/// | 0x0501-0x05FF | Security errors  |
///
/// ## Usage
///
/// ```dart
/// throw UnifiedDeviceException(
///   'Connection failed',
///   errorCode: ErrorCodes.transportConnectionFailed,
/// );
/// ```
class ErrorCodes {
  ErrorCodes._();

  // ---- Transport Errors (0x0001 - 0x00FF) ----

  /// Device not found during scan.
  static const int transportDeviceNotFound = 0x0001;

  /// Failed to establish BLE connection.
  static const int transportConnectionFailed = 0x0002;

  /// Connection was unexpectedly lost.
  static const int transportConnectionLost = 0x0003;

  /// Operation timed out at the transport layer.
  static const int transportTimeout = 0x0004;

  /// Required GATT service not found.
  static const int transportServiceNotFound = 0x0005;

  /// Write operation failed.
  static const int transportWriteFailed = 0x0006;

  /// Read operation failed.
  static const int transportReadFailed = 0x0007;

  /// Notification subscription failed.
  static const int transportNotificationFailed = 0x0008;

  /// Bluetooth is powered off.
  static const int transportBluetoothOff = 0x0009;

  /// Bluetooth adapter not available.
  static const int transportBluetoothUnavailable = 0x000A;

  /// Insufficient Bluetooth permissions.
  static const int transportPermissionDenied = 0x000B;

  /// BLE MTU negotiation failed.
  static const int transportMtuNegotiationFailed = 0x000C;

  // ---- Protocol Errors (0x0101 - 0x01FF) ----

  /// Unsupported or unknown command.
  static const int protocolUnsupportedCommand = 0x0101;

  /// Invalid command parameters.
  static const int protocolInvalidParameters = 0x0102;

  /// Device returned a NACK response.
  static const int protocolNackReceived = 0x0103;

  /// Response payload parsing failed.
  static const int protocolResponseParsingFailed = 0x0104;

  /// Unexpected response sequence number.
  static const int protocolUnexpectedSequence = 0x0105;

  /// Device is in an invalid state for the command.
  static const int protocolInvalidDeviceState = 0x0106;

  /// Command not allowed in the current mode.
  static const int protocolCommandNotAllowed = 0x0107;

  /// CRC validation failed on a received frame.
  static const int protocolCrcMismatch = 0x0108;

  /// Frame delimiter (SOF/EOF) mismatch.
  static const int protocolFrameDelimiterMismatch = 0x0109;

  /// Payload exceeds maximum allowed size.
  static const int protocolPayloadTooLarge = 0x010A;

  // ---- Session Errors (0x0201 - 0x02FF) ----

  /// Session bootstrap failed.
  static const int sessionBootstrapFailed = 0x0201;

  /// Session open (RTC sync) failed.
  static const int sessionOpenFailed = 0x0202;

  /// Session close failed.
  static const int sessionCloseFailed = 0x0203;

  /// Heartbeat ACK not received within timeout.
  static const int sessionHeartbeatMissed = 0x0204;

  /// Maximum missed heartbeats exceeded.
  static const int sessionHeartbeatTimeout = 0x0205;

  /// Transport open (btTransportOpen) failed.
  static const int sessionTransportOpenFailed = 0x0206;

  // ---- Command Errors (0x0301 - 0x03FF) ----

  /// Command timed out waiting for ACK.
  static const int commandAckTimeout = 0x0301;

  /// Command timed out waiting for DATA response.
  static const int commandDataTimeout = 0x0302;

  /// Command was cancelled by the caller.
  static const int commandCancelled = 0x0303;

  /// Command blocked because session is not active.
  static const int commandBlockedNoSession = 0x0304;

  // ---- Device Errors (0x0401 - 0x04FF) ----

  /// Device returned a general error status.
  static const int deviceGeneralError = 0x0401;

  /// Device reported a hardware fault.
  static const int deviceHardwareFault = 0x0402;

  /// Device reported a sensor fault.
  static const int deviceSensorFault = 0x0403;

  /// Device storage is full.
  static const int deviceStorageFull = 0x0404;

  /// Device battery is critically low.
  static const int deviceBatteryLow = 0x0405;

  /// Device calibration is required.
  static const int deviceCalibrationRequired = 0x0406;

  // ---- Security Errors (0x0501 - 0x05FF) ----

  /// Encryption/decryption operation failed.
  static const int securityEncryptionFailed = 0x0501;

  /// Authentication with the device failed.
  static const int securityAuthenticationFailed = 0x0502;

  /// Device rejected the encryption key.
  static const int securityKeyRejected = 0x0503;
}