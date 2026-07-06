import 'decoded_tlv.dart';

/// Official `last_report` payload decoded from TLVs.
class UcpLastReport {
  final int? reportId;
  final int? testNumber;
  final double? nitrogen;
  final double? phosphorus;
  final double? potassium;
  final double? moisture;
  final double? ph;
  final double? ec;
  final double? temperature;
  final String? error;
  final List<DecodedTlv> tlvs;

  const UcpLastReport({
    this.reportId,
    this.testNumber,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.moisture,
    this.ph,
    this.ec,
    this.temperature,
    this.error,
    this.tlvs = const <DecodedTlv>[],
  });
}
