import 'decoded_tlv.dart';

/// Official NACK details decoded from TLVs.
class UcpNackDetails {
  final int? status;
  final int? errorCode;
  final String? text;
  final List<DecodedTlv> tlvs;

  const UcpNackDetails({
    this.status,
    this.errorCode,
    this.text,
    this.tlvs = const <DecodedTlv>[],
  });
}
