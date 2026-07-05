import 'device_frame.dart';
import '../bytes/endian_utils.dart';
import '../crc/crc16_ccitt.dart';
import '../../protocol/constants/protocol_constants.dart';

/// Builds raw byte frames ready for BLE transmission.
///
/// Wire format (17 bytes minimum with empty payload):
///   SOF(1) VER(1) PRODUCT(2) ADDR(4) OP(1) CMD(1) SEQ(1) FLAGS(1)
///   LEN_H(1) LEN_L(1) PAYLOAD(n) CRC_H(1) CRC_L(1) EOF(1)
///
/// Constants:
///   SOF = 0xDD, EOF = 0x77
///   Header = 10 bytes (SOF through LEN)
///   Trailer = 3 bytes (CRC + EOF)
///   LEN = uint16 big-endian
///   CRC = CRC-16-CCITT, output big-endian
///
/// ## CRC Configuration
///
/// The [crcRangeStart] and [crcRangeEnd] control which bytes are included
/// in the CRC calculation, defined as offsets into the frame byte array
/// (including SOF/EOF). The default range is `1` to the last payload byte,
/// meaning VER through PAYLOAD (excluding SOF, CRC, and EOF).
///
/// To include SOF in the CRC, set [crcRangeStart] to `0`.
/// To change CRC parameters (polynomial, init, finalXor), pass a custom
/// [Crc16Ccitt] instance via [crc].
class FrameBuilder {
  /// The SOF (Start of Frame) delimiter byte.
  final int sof;

  /// The EOF (End of Frame) delimiter byte.
  final int eof;

  /// The CRC calculator instance (configurable polynomial/init/finalXor).
  final Crc16Ccitt crc;

  /// First index (inclusive) of the CRC input range in the frame byte array.
  ///
  /// Default: `1` (skip SOF at index 0, start at VER).
  final int crcRangeStart;

  /// Last index (inclusive) of the CRC input range in the frame byte array.
  ///
  /// If `null` (default), CRC is computed up to and including the
  /// last payload byte (excluding CRC and EOF).
  final int? crcRangeEnd;

  /// Creates a [FrameBuilder] with the given configuration.
  ///
  /// [sof] defaults to [ProtocolConstants.sof] (0xDD).
  /// [eof] defaults to [ProtocolConstants.eof] (0x77).
  /// [crc] defaults to [Crc16Ccitt.standard()] (0x1021, init 0xFFFF, xor 0x0000).
  /// [crcRangeStart] defaults to `1` (skip SOF, start at VER).
  /// [crcRangeEnd] defaults to `null` (up to last payload byte).
  FrameBuilder({
    this.sof = ProtocolConstants.sof,
    this.eof = ProtocolConstants.eof,
    Crc16Ccitt? crc,
    this.crcRangeStart = 1,
    this.crcRangeEnd,
  }) : crc = crc ?? Crc16Ccitt.standard();

  /// Builds a complete frame byte array from individual fields.
  ///
  /// The returned bytes include SOF and EOF and are ready to send over BLE.
  ///
  /// Throws [ArgumentError] if any one-byte field is outside 0-255,
  /// if [productId] or [crcValue] is outside 0-65535,
  /// if [address] is outside 0-4294967295,
  /// if [payload] exceeds 65535 bytes, or if any payload byte is outside 0-255.
  List<int> build({
    required int version,
    required int productId,
    required int address,
    required int op,
    required int commandId,
    required int sequence,
    required int flags,
    List<int> payload = const [],
    int crcValue = 0,
  }) {
    // Validate inputs
    _validateUint8(version, 'version');
    _validateUint16(productId, 'productId');
    _validateUint32(address, 'address');
    _validateUint8(op, 'op');
    _validateUint8(commandId, 'commandId');
    _validateUint8(sequence, 'sequence');
    _validateUint8(flags, 'flags');
    _validatePayload(payload);

    // Build the byte array: SOF + header + payload + CRC + EOF
    final frameBytes = <int>[
      sof,
      version,
      ...EndianUtils.uint16ToBytesBE(productId),
      ...EndianUtils.uint32ToBytesBE(address),
      op,
      commandId,
      sequence,
      flags,
      ...EndianUtils.uint16ToBytesBE(payload.length),
      ...payload,
    ];

    // Compute CRC over the configured range
    final crcInputEnd = crcRangeEnd ?? frameBytes.length;
    final crcInput = frameBytes.sublist(crcRangeStart, crcInputEnd);
    final crcBytes = crc.computeBytesBE(crcInput);

    // Append CRC and EOF
    frameBytes.addAll(crcBytes);
    frameBytes.add(eof);

    return frameBytes;
  }

  /// Builds a complete frame byte array from a [DeviceFrame].
  ///
  /// This is a convenience wrapper around [build] that extracts fields
  /// from the frame object. The [DeviceFrame] already validates its fields.
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
      crcValue: frame.crc,
    );
  }

  /// Returns the frame header size in bytes: SOF + 9 header fields.
  static int get headerSize => ProtocolConstants.headerSize;

  /// Returns the frame trailer size in bytes: CRC(2) + EOF(1).
  static int get trailerSize => ProtocolConstants.trailerSize;

  // ---- Validation ----

  static void _validateUint8(int value, String name) {
    if (value < 0 || value > 255) {
      throw ArgumentError('$name must be 0-255, but got $value');
    }
  }

  static void _validateUint16(int value, String name) {
    if (value < 0 || value > 65535) {
      throw ArgumentError('$name must be 0-65535, but got $value');
    }
  }

  static void _validateUint32(int value, String name) {
    if (value < 0 || value > 4294967295) {
      throw ArgumentError('$name must be 0-4294967295, but got $value');
    }
  }

  static void _validatePayload(List<int> payload) {
    if (payload.length > 65535) {
      throw ArgumentError(
        'payload length must not exceed 65535, but got ${payload.length}',
      );
    }
    for (var i = 0; i < payload.length; i++) {
      if (payload[i] < 0 || payload[i] > 255) {
        throw ArgumentError(
          'payload byte at index $i must be 0-255, but got ${payload[i]}',
        );
      }
    }
  }
}
