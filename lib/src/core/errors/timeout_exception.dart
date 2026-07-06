import 'unified_device_exception.dart';

/// Exception thrown when an operation times out.
class TimeoutException extends UnifiedDeviceException {
  final Duration timeoutDuration;
  final String operation;

  const TimeoutException(
    super.message, {
    required this.timeoutDuration,
    required this.operation,
    super.errorCode,
    super.stackTrace,
  });

  @override
  String toString() =>
      'TimeoutException: $operation timed out after $timeoutDuration';
}
