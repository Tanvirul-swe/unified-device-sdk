import '../../core/bytes/endian_utils.dart';
import '../../core/errors/protocol_exception.dart';
import '../models/tlv.dart';

/// Parser for `TYPE LENGTH_H LENGTH_L VALUE` payload streams.
class TlvParser {
  const TlvParser();

  List<Tlv> parseAll(List<int> bytes) {
    final tlvs = <Tlv>[];
    var offset = 0;

    while (offset < bytes.length) {
      final remaining = bytes.length - offset;
      if (remaining < 3) {
        throw const ProtocolException(
          'Incomplete TLV header',
          protocolErrorType: ProtocolErrorType.responseParsingFailed,
        );
      }

      final type = bytes[offset];
      final length = EndianUtils.bytesToUint16BE(bytes, offset + 1);
      final valueStart = offset + 3;
      final valueEnd = valueStart + length;
      if (valueEnd > bytes.length) {
        throw const ProtocolException(
          'TLV length exceeds available payload bytes',
          protocolErrorType: ProtocolErrorType.responseParsingFailed,
        );
      }

      tlvs.add(Tlv(type: type, value: bytes.sublist(valueStart, valueEnd)));
      offset = valueEnd;
    }

    return List<Tlv>.unmodifiable(tlvs);
  }
}
