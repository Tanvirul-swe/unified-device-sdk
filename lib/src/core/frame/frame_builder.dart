import 'device_frame.dart';
import '../bytes/endian_utils.dart';
import '../crc/crc16_ccitt.dart';
import '../../protocol/constants/protocol_constants.dart';

/// Builds raw byte frames ready for BLE transmission.
///
/// Correct wire format:
///
/// SOF(1)
/// VER(1)
/// PRODUCT(1)
/// ADDR(1)
/// OP(1)
/// CMD(1)
/// SEQ(1)
/// FLAGS(1)
/// LEN_H(1)
/// LEN_L(1)
/// PAYLOAD(n)
/// CRC_H(1)
/// CRC_L(1)
/// EOF(1)
///
/// Empty payload frame size:
/// 10-byte header + 0 payload + 2-byte CRC + 1-byte EOF = 13 bytes
///
/// CRC range:
/// VER through PAYLOAD
/// That means exclude SOF, CRC, EOF.
class FrameBuilder {
  final int sof;
  final int eof;
  final Crc16Ccitt crc;

  /// Default: 1, meaning CRC starts from VER.
  final int crcRangeStart;

  /// If null, CRC ends at last payload byte.
  final int? crcRangeEnd;

  FrameBuilder({
    this.sof = ProtocolConstants.sof,
    this.eof = ProtocolConstants.eof,
    Crc16Ccitt? crc,
    this.crcRangeStart = 1,
    this.crcRangeEnd,
  }) : crc = crc ?? Crc16Ccitt.standard();

  List<int> build({
    required int version,
    required int productId,
    required int address,
    required int op,
    required int commandId,
    required int sequence,
    required int flags,
    List<int> payload = const [],
  }) {
    _validateUint8(version, 'version');

    // As per document, PRODUCT is 1 byte.
    _validateUint8(productId, 'productId');

    // As per document, ADDR is 1 byte.
    _validateUint8(address, 'address');

    _validateUint8(op, 'op');
    _validateUint8(commandId, 'commandId');
    _validateUint8(sequence, 'sequence');
    _validateUint8(flags, 'flags');
    _validatePayload(payload);

    final payloadLength = payload.length;

    final frameBytes = <int>[
      sof,
      version,
      productId,
      address,
      op,
      commandId,
      sequence,
      flags,
      ...EndianUtils.uint16ToBytesBE(payloadLength),
      ...payload,
    ];

    // CRC from VER through PAYLOAD.
    // frameBytes currently contains SOF + header + payload only.
    // sublist(1, frameBytes.length) = VER through PAYLOAD.
    final crcInputEnd = crcRangeEnd ?? frameBytes.length;
    final crcInput = frameBytes.sublist(crcRangeStart, crcInputEnd);
    final crcBytes = crc.computeBytesBE(crcInput);

    frameBytes.addAll(crcBytes);
    frameBytes.add(eof);

    return frameBytes;
  }

  List<int> buildFromFrame(DeviceFrame frame) {
    return build(
      version: frame.version,
      productId: frame.productId,
      address: frame.address,
      op: frame.op,
      commandId: frame.commandId,
      sequence: frame.sequence,
      flags: frame.flags,
      payload: frame.payload,
    );
  }

  /// Header size:
  /// SOF + VER + PRODUCT + ADDR + OP + CMD + SEQ + FLAGS + LEN_H + LEN_L
  /// = 10 bytes
  static int get headerSize => 10;

  /// Trailer size:
  /// CRC_H + CRC_L + EOF
  /// = 3 bytes
  static int get trailerSize => 3;

  static void _validateUint8(int value, String name) {
    if (value < 0 || value > 255) {
      throw ArgumentError('$name must be 0-255, but got $value');
    }
  }

  static void _validatePayload(List<int> payload) {
    if (payload.length > 65535) {
      throw ArgumentError(
        'payload length must not exceed 65535, but got ${payload.length}',
      );
    }

    for (var i = 0; i < payload.length; i++) {
      final byte = payload[i];

      if (byte < 0 || byte > 255) {
        throw ArgumentError(
          'payload byte at index $i must be 0-255, but got $byte',
        );
      }
    }
  }
}
