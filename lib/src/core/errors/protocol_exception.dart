import 'unified_device_exception.dart';

/// Exception thrown for higher-level protocol errors.
class ProtocolException extends UnifiedDeviceException {
  final ProtocolErrorType protocolErrorType;

  const ProtocolException(
    super.message, {
    super.errorCode,
    super.stackTrace,
    this.protocolErrorType = ProtocolErrorType.unknown,
  });

  @override
  String toString() => 'ProtocolException[$protocolErrorType]: $message';
}

/// Categorizes protocol errors for easier handling.
enum ProtocolErrorType {
  /// Unsupported command.
  unsupportedCommand,

  /// Invalid command parameters.
  invalidParameters,

  /// Device returned a NACK response.
  nackReceived,

  /// Response parsing failed.
  responseParsingFailed,

  /// Unexpected response sequence.
  unexpectedSequence,

  /// Device is in an invalid state.
  invalidDeviceState,

  /// Command not allowed in current mode.
  commandNotAllowed,

  /// Unknown or uncategorized error.
  unknown,
}