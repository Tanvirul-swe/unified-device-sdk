/// Base exception class for all Unified Device SDK errors.
class UnifiedDeviceException implements Exception {
  final String message;
  final int? errorCode;
  final StackTrace? stackTrace;

  const UnifiedDeviceException(
    this.message, {
    this.errorCode,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('UnifiedDeviceException: $message');
    if (errorCode != null) {
      buffer.write(' (errorCode: $errorCode)');
    }
    return buffer.toString();
  }
}