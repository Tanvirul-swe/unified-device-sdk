import 'unified_device_exception.dart';

/// Exception thrown when a CRC check fails.
class CrcException extends UnifiedDeviceException {
  final int expectedCrc;
  final int actualCrc;

  const CrcException(
    super.message, {
    required this.expectedCrc,
    required this.actualCrc,
    super.errorCode,
    super.stackTrace,
  });

  @override
  String toString() =>
      'CrcException: $message (expected: 0x${expectedCrc.toRadixString(16).toUpperCase().padLeft(4, '0')}, '
      'actual: 0x${actualCrc.toRadixString(16).toUpperCase().padLeft(4, '0')})';
}