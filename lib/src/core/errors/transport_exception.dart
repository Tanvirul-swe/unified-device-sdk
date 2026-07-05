import 'unified_device_exception.dart';

/// Exception thrown for transport-level errors (BLE, serial, etc.).
class TransportException extends UnifiedDeviceException {
  final TransportErrorType errorType;

  const TransportException(
    super.message, {
    super.errorCode,
    super.stackTrace,
    this.errorType = TransportErrorType.unknown,
  });

  @override
  String toString() => 'TransportException[$errorType]: $message';
}

/// Categorizes transport errors for easier handling.
enum TransportErrorType {
  /// Device not found during scan.
  deviceNotFound,

  /// Failed to establish connection.
  connectionFailed,

  /// Connection was unexpectedly lost.
  connectionLost,

  /// Operation timed out.
  timeout,

  /// Service or characteristic not found.
  serviceNotFound,

  /// Write operation failed.
  writeFailed,

  /// Read operation failed.
  readFailed,

  /// Notifications not supported.
  notificationFailed,

  /// Bluetooth is powered off.
  bluetoothOff,

  /// Bluetooth adapter not available.
  bluetoothUnavailable,

  /// Insufficient permissions.
  permissionDenied,

  /// Unknown or uncategorized error.
  unknown,
}