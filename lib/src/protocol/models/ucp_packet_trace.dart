import '../../core/frame/device_frame.dart';
import 'decoded_tlv.dart';

enum UcpPacketDirection { tx, rx }

/// Timestamped packet trace entry for diagnostics.
class UcpPacketTrace {
  final UcpPacketDirection direction;
  final List<int> bytes;
  final DeviceFrame? frame;
  final List<DecodedTlv> decodedTlvs;
  final DateTime timestamp;

  UcpPacketTrace({
    required this.direction,
    required List<int> bytes,
    this.frame,
    this.decodedTlvs = const <DecodedTlv>[],
    DateTime? timestamp,
  }) : bytes = List<int>.unmodifiable(bytes),
       timestamp = timestamp ?? DateTime.now();

  String get directionLabel => direction == UcpPacketDirection.tx ? 'TX' : 'RX';
}
