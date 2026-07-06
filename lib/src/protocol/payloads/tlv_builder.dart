import '../../core/bytes/endian_utils.dart';
import '../models/tlv.dart';

/// Builder for TLV-encoded payloads.
class TlvBuilder {
  final List<Tlv> _tlvs = <Tlv>[];

  TlvBuilder add(Tlv tlv) {
    _tlvs.add(tlv);
    return this;
  }

  TlvBuilder addBytes(int type, List<int> value) {
    return add(Tlv(type: type, value: value));
  }

  TlvBuilder addAscii(int type, String value) {
    return addBytes(type, value.codeUnits);
  }

  TlvBuilder addUtf8(int type, String value) {
    return addBytes(type, value.codeUnits);
  }

  TlvBuilder addUint8(int type, int value) {
    return addBytes(type, [value & 0xFF]);
  }

  TlvBuilder addUint16BE(int type, int value) {
    return addBytes(type, EndianUtils.uint16ToBytesBE(value));
  }

  TlvBuilder addUint32BE(int type, int value) {
    return addBytes(type, EndianUtils.uint32ToBytesBE(value));
  }

  TlvBuilder addUint64BE(int type, int value) {
    return addBytes(type, EndianUtils.uint64ToBytesBE(value));
  }

  List<Tlv> buildTlvs() => List<Tlv>.unmodifiable(_tlvs);

  List<int> build() {
    return <int>[for (final tlv in _tlvs) ...tlv.toBytes()];
  }

  void reset() {
    _tlvs.clear();
  }

  static List<int> encode(List<Tlv> tlvs) {
    return <int>[for (final tlv in tlvs) ...tlv.toBytes()];
  }
}
