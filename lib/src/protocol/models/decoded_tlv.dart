import '../constants/tlv_types.dart';
import 'tlv.dart';

/// Human-friendly TLV decode used by logs and typed parsers.
class DecodedTlv {
  final Tlv tlv;
  final String typeName;
  final Object value;

  const DecodedTlv({
    required this.tlv,
    required this.typeName,
    required this.value,
  });

  factory DecodedTlv.fromTlv(Tlv tlv) {
    return DecodedTlv(
      tlv: tlv,
      typeName: TlvTypes.nameOf(tlv.type),
      value: TlvTypes.decodeValue(tlv),
    );
  }

  int get type => tlv.type;
  int get length => tlv.length;

  String get displayValue {
    final currentValue = value;
    if (currentValue is List<int>) {
      return currentValue
          .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' ');
    }
    return '$currentValue';
  }
}
