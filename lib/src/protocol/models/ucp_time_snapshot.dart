import 'decoded_tlv.dart';

/// Official `time` DATA payload decoded from TLVs.
class UcpTimeSnapshot {
  final int? epochSeconds;
  final int? uptimeSeconds;
  final String? text;
  final List<DecodedTlv> tlvs;

  const UcpTimeSnapshot({
    this.epochSeconds,
    this.uptimeSeconds,
    this.text,
    this.tlvs = const <DecodedTlv>[],
  });
}
