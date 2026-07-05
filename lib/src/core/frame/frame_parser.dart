import 'device_frame.dart';
import '../bytes/endian_utils.dart';
import '../crc/crc16_ccitt.dart';
import '../errors/frame_exception.dart';
import '../errors/crc_exception.dart';
import '../errors/protocol_exception.dart';
import '../../protocol/constants/protocol_constants.dart';

/// Parses raw frame bytes into [DeviceFrame] objects with full validation.
///
/// Expected wire format (17 bytes minimum with empty payload):
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
/// All parse methods throw typed exceptions on failure:
///   - [FrameException] for SOF/EOF/length errors
///   - [CrcException] for CRC mismatch
///   - [ProtocolException] for invalid field values
///
/// ## CRC Configuration
///
/// The [crcRangeStart] and [crcRangeEnd] control which bytes are included
/// in the CRC calculation, and must match the settings used by [FrameBuilder]
/// on the sending side. Default: VER through PAYLOAD (excludes SOF, CRC, EOF).
class FrameParser {
  /// The expected SOF (Start of Frame) delimiter byte.
  final int sof;

  /// The expected EOF (End of Frame) delimiter byte.
  final int eof;

  /// The CRC calculator instance (configurable polynomial/init/finalXor).
  final Crc16Ccitt crc;

  /// First index (inclusive) of the CRC input range in the frame byte array.
  ///
  /// Must match the [FrameBuilder.crcRangeStart] used on the sending side.
  final int crcRangeStart;

  /// Last index (inclusive) of the CRC input range in the frame byte array.
  ///
  /// If `null` (default), CRC is computed up to and including the
  /// last payload byte (excluding CRC and EOF).
  /// Must match the [FrameBuilder.crcRangeEnd] used on the sending side.
  final int? crcRangeEnd;

  /// Creates a [FrameParser] with the given configuration.
  ///
  /// Default settings match [FrameBuilder] defaults:
  ///   [sof] = 0xDD, [eof] = 0x77
  ///   [crc] = standard CRC-16-CCITT
  ///   [crcRangeStart] = 1 (skip SOF)
  ///   [crcRangeEnd] = null (up to last payload byte)
  FrameParser({
    this.sof = ProtocolConstants.sof,
    this.eof = ProtocolConstants.eof,
    Crc16Ccitt? crc,
    this.crcRangeStart = 1,
    this.crcRangeEnd,
  }) : crc = crc ?? Crc16Ccitt.standard();

  /// Parses a complete frame from raw bytes.
  ///
  /// The input [bytes] must include SOF and EOF delimiters.
  ///
  /// Returns a [DeviceFrame] on success.
  ///
  /// Throws:
  ///   [FrameException] if frame is too short, SOF/EOF mismatch, or length mismatch
  ///   [CrcException] if CRC validation fails
  ///   [ProtocolException] if any field value is invalid
  DeviceFrame parse(List<int> bytes) {
    // Validate minimum size
    const minSize = ProtocolConstants.minFrameSize;
    if (bytes.length < minSize) {
      throw FrameException(
        'Frame too short: ${bytes.length} bytes (minimum $minSize)',
        frameErrorType: FrameErrorType.frameTooShort,
      );
    }

    // Validate SOF
    if (bytes[0] != sof) {
      throw FrameException(
        'Invalid SOF: expected 0x${sof.toRadixString(16).toUpperCase()}, '
        'got 0x${bytes[0].toRadixString(16).toUpperCase()}',
        frameErrorType: FrameErrorType.invalidSof,
        errorCode: bytes[0],
      );
    }

    // Validate EOF
    if (bytes.last != eof) {
      throw FrameException(
        'Invalid EOF: expected 0x${eof.toRadixString(16).toUpperCase()}, '
        'got 0x${bytes.last.toRadixString(16).toUpperCase()}',
        frameErrorType: FrameErrorType.invalidEof,
        errorCode: bytes.last,
      );
    }

    // Parse header fields
    final version = bytes[1];
    final productId = EndianUtils.bytesToUint16BE(bytes, 2);
    final address = EndianUtils.bytesToUint32BE(bytes, 4);
    final op = bytes[8];
    final commandId = bytes[9];
    final sequence = bytes[10];
    final flags = bytes[11];
    final declaredPayloadLength = EndianUtils.bytesToUint16BE(bytes, 12);

    // Validate declared length against actual frame size
    // Header: SOF(1) + VER(1) + PROD(2) + ADDR(4) + OP(1) + CMD(1) + SEQ(1) + FLAGS(1) + LEN(2) = 14 before payload
    const headerBytes = 14;
    final expectedTotalSize = headerBytes + declaredPayloadLength + ProtocolConstants.crcSize + 1; // +1 for EOF
    if (bytes.length != expectedTotalSize) {
      throw FrameException(
        'Length mismatch: header declares payload of $declaredPayloadLength bytes '
        '($expectedTotalSize total), but actual frame is ${bytes.length} bytes',
        frameErrorType: FrameErrorType.lengthMismatch,
        errorCode: declaredPayloadLength,
      );
    }

    // Extract payload
    const payloadStart = headerBytes;
    final payloadEnd = payloadStart + declaredPayloadLength;
    final payload = bytes.sublist(payloadStart, payloadEnd);

    // Extract CRC (big-endian)
    final crcHigh = bytes[payloadEnd];
    final crcLow = bytes[payloadEnd + 1];
    final declaredCrc = (crcHigh << 8) | crcLow;

    // Compute CRC over the configured range
    // frameBytes = SOF + VER + PROD + ADDR + OP + CMD + SEQ + FLAGS + LEN + PAYLOAD
    // CRC range is indices [crcRangeStart, crcRangeEnd) in the full array
    final crcInputEnd = crcRangeEnd ?? payloadEnd; // up to last payload byte
    final crcInput = bytes.sublist(crcRangeStart, crcInputEnd);
    final computedCrc = crc.compute(crcInput);

    // Validate CRC
    if (computedCrc != declaredCrc) {
      throw CrcException(
        'CRC mismatch',
        expectedCrc: computedCrc,
        actualCrc: declaredCrc,
      );
    }

    // Build DeviceFrame (validates all field ranges)
    try {
      return DeviceFrame(
        version: version,
        productId: productId,
        address: address,
        op: op,
        commandId: commandId,
        sequence: sequence,
        flags: flags,
        payload: payload,
        crc: declaredCrc,
      );
    } on ArgumentError catch (e) {
      throw ProtocolException(
        'Invalid frame field: ${e.message}',
        protocolErrorType: ProtocolErrorType.invalidParameters,
        errorCode: null,
      );
    }
  }

  /// Extracts the payload bytes from a raw frame without full validation.
  ///
  /// Only checks SOF, EOF, and minimum length. Useful for quick inspection.
  /// Returns `null` if the frame cannot be safely inspected.
  List<int>? extractPayload(List<int> bytes) {
    const minSize = ProtocolConstants.minFrameSize;
    if (bytes.length < minSize) return null;
    if (bytes[0] != sof || bytes.last != eof) return null;

    final declaredPayloadLength = EndianUtils.bytesToUint16BE(bytes, 12);
    const headerBytes = 14;
    final payloadEnd = headerBytes + declaredPayloadLength;
    final expectedTotalSize = headerBytes + declaredPayloadLength + 3; // CRC(2) + EOF(1)

    if (bytes.length < expectedTotalSize) return null;
    return bytes.sublist(headerBytes, payloadEnd);
  }
}
