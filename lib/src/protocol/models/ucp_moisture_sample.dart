import 'decoded_tlv.dart';

/// Moisture STREAM sample decoded from TLVs.
class UcpMoistureSample {
  final int? rawValue;
  final double? moisturePercent;
  final String? text;
  final List<DecodedTlv> tlvs;

  const UcpMoistureSample({
    this.rawValue,
    this.moisturePercent,
    this.text,
    this.tlvs = const <DecodedTlv>[],
  });
}
