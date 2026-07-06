import '../../core/errors/protocol_exception.dart';
import '../../core/response/device_response.dart';
import '../../protocol/constants/operation_codes.dart';
import '../models/ucp_nack_details.dart';
import 'common_response_parser.dart';

/// Optional parser for generic NACK responses.
class NackParser {
  final CommonResponseParser _responseParser;

  const NackParser({
    CommonResponseParser responseParser = const CommonResponseParser(),
  }) : _responseParser = responseParser;

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

    final details = parseDetails(response);
    return ProtocolException(
      details.text ?? response.errorMessage ?? 'Device returned NACK',
      errorCode: details.errorCode ?? response.flags,
      protocolErrorType: ProtocolErrorType.nackReceived,
    );
  }

  UcpNackDetails parseDetails(DeviceResponse response) {
    return _responseParser.parseNack(response);
  }
}
