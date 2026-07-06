import '../bytes/endian_utils.dart';
import '../crc/crc16_ccitt.dart';
import '../../protocol/constants/command_classes.dart';
import '../../protocol/constants/profile_ids.dart';
import '../../protocol/constants/protocol_constants.dart';
import '../../protocol/constants/ucp_addresses.dart';
import '../../protocol/models/tlv.dart';
import '../../protocol/payloads/tlv_builder.dart';
import 'device_frame.dart';

/// Builds raw bytes for the official UCP frame layout.
class UcpFrameBuilder {
  final int sof;
  final int eof;
  final Crc16Ccitt crc;

  UcpFrameBuilder({
    this.sof = ProtocolConstants.sof,
    this.eof = ProtocolConstants.eof,
    Crc16Ccitt? crc,
  }) : crc = crc ?? Crc16Ccitt.ccittFalse();

  List<int> build({
    required int version,
    required int productId,
    int profileId = ProfileIds.defaultProfile,
    int? address,
    int? sourceAddress,
    int? destinationAddress,
    required int op,
    int commandClass = CommandClasses.system,
    required int commandId,
    required int sequence,
    required int flags,
    List<int> payload = const [],
    List<Tlv> tlvs = const [],
  }) {
    _validateUint8(version, 'version');
    _validateUint8(productId, 'productId');
    _validateUint8(profileId, 'profileId');

    final resolvedSource = sourceAddress ?? UcpAddresses.defaultSource;
    final resolvedDestination =
        destinationAddress ?? address ?? UcpAddresses.defaultDestination;
    _validateUint8(resolvedSource, 'sourceAddress');
    _validateUint8(resolvedDestination, 'destinationAddress');

    _validateUint8(op, 'op');
    _validateUint8(commandClass, 'commandClass');
    _validateUint8(commandId, 'commandId');
    _validateUint16(sequence, 'sequence');
    _validateUint8(flags, 'flags');

    final payloadBytes = _resolvePayload(payload: payload, tlvs: tlvs);
    _validatePayload(payloadBytes);

    final frameWithoutCrc = <int>[
      sof,
      version,
      productId,
      profileId,
      resolvedSource,
      resolvedDestination,
      op,
      commandClass,
      commandId,
      ...EndianUtils.uint16ToBytesBE(sequence),
      flags,
      ...EndianUtils.uint16ToBytesBE(payloadBytes.length),
      ...payloadBytes,
    ];

    final crcBytes = crc.computeBytesBE(
      frameWithoutCrc.sublist(ProtocolConstants.versionOffset),
    );

    return <int>[...frameWithoutCrc, ...crcBytes, eof];
  }

  List<int> buildFromFrame(UcpFrame frame) {
    return build(
      version: frame.version,
      productId: frame.productId,
      profileId: frame.profileId,
      sourceAddress: frame.sourceAddress,
      destinationAddress: frame.destinationAddress,
      op: frame.op,
      commandClass: frame.commandClass,
      commandId: frame.commandId,
      sequence: frame.sequence,
      flags: frame.flags,
      payload: frame.payload,
      tlvs: frame.tlvs,
    );
  }

  static List<int> _resolvePayload({
    required List<int> payload,
    required List<Tlv> tlvs,
  }) {
    if (payload.isNotEmpty && tlvs.isNotEmpty) {
      final encodedTlvs = TlvBuilder.encode(tlvs);
      if (!_listEquals(payload, encodedTlvs)) {
        throw ArgumentError('payload bytes do not match encoded TLVs');
      }
      return payload;
    }
    if (tlvs.isNotEmpty) {
      return TlvBuilder.encode(tlvs);
    }
    return payload;
  }

  static void _validateUint8(int value, String name) {
    if (value < 0 || value > 0xFF) {
      throw ArgumentError('$name must be 0-255, but got $value');
    }
  }

  static void _validateUint16(int value, String name) {
    if (value < 0 || value > 0xFFFF) {
      throw ArgumentError('$name must be 0-65535, but got $value');
    }
  }

  static void _validatePayload(List<int> payload) {
    if (payload.length > ProtocolConstants.maxPayloadSize) {
      throw ArgumentError(
        'payload length must not exceed ${ProtocolConstants.maxPayloadSize}, '
        'but got ${payload.length}',
      );
    }
    for (var i = 0; i < payload.length; i++) {
      _validateUint8(payload[i], 'payload[$i]');
    }
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Backward-compatible alias class.
class FrameBuilder extends UcpFrameBuilder {
  FrameBuilder({
    super.sof,
    super.eof,
    super.crc,
    int crcRangeStart = 1,
    int? crcRangeEnd,
  }) : assert(crcRangeStart == 1 || crcRangeStart == 0),
       assert(crcRangeEnd == null);
}
