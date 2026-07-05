import '../../core/errors/protocol_exception.dart';
import '../../core/response/device_response.dart';
import '../../protocol/constants/operation_codes.dart';

/// Optional parser for generic NACK responses.
class NackParser {
  const NackParser();

  /// Converts a NACK response into a [ProtocolException].
  ///
  /// By convention, if the payload is non-empty the first byte is treated
  /// as the device-provided error code.
  ProtocolException parse(DeviceResponse response) {
    if (response.op != OperationCodes.nack) {
      throw const ProtocolException(
        'Response is not a NACK frame',
        protocolErrorType: ProtocolErrorType.responseParsingFailed,
      );
    }

    return ProtocolException(
      response.errorMessage ?? 'Device returned NACK',
      errorCode: response.payload.isNotEmpty ? response.payload.first : response.flags,
      protocolErrorType: ProtocolErrorType.nackReceived,
    );
  }
}
