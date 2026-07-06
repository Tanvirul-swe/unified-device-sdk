import 'unified_device_exception.dart';

/// Exception thrown when frame-level protocol errors occur.
class FrameException extends UnifiedDeviceException {
  final FrameErrorType frameErrorType;

  const FrameException(
    super.message, {
    super.errorCode,
    super.stackTrace,
    this.frameErrorType = FrameErrorType.unknown,
  });

  @override
  String toString() => 'FrameException[$frameErrorType]: $message';
}

/// Categorizes frame errors for easier handling.
enum FrameErrorType {
  /// Frame is too short to be valid.
  frameTooShort,

  /// Frame is too long.
  frameTooLong,

  /// Invalid start-of-frame delimiter.
  invalidSof,

  /// Invalid end-of-frame delimiter.
  invalidEof,

  /// Frame length field mismatch.
  lengthMismatch,

  /// CRC check failed.
  crcMismatch,

  /// Unknown or unsupported frame type.
  unknownFrameType,

  /// Invalid protocol version.
  invalidProtocolVersion,

  /// Payload parsing failed.
  payloadParsingFailed,

  /// Unknown or uncategorized error.
  unknown,
}
