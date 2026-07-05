import 'device_frame.dart';
import 'frame_parser.dart';
import '../bytes/endian_utils.dart';
import '../errors/frame_exception.dart';
import '../errors/crc_exception.dart';
import '../../protocol/constants/protocol_constants.dart';

/// A buffer that accumulates incoming BLE notification bytes and assembles
/// them into complete [DeviceFrame] objects.
///
/// BLE notifications may deliver partial frames or multiple frames in a single
/// notification. This buffer handles both cases:
///
/// 1. Appends incoming bytes to an internal buffer.
/// 2. Discards garbage bytes before SOF (0xDD).
/// 3. Once at least the header is available, reads LEN_H/LEN_L to determine
///    the total frame size.
/// 4. Waits until the full frame is available, then parses it with [FrameParser].
/// 5. Returns parsed frames and keeps incomplete bytes for the next call.
///
/// ## Invalid Frame Handling
///
/// If [FrameParser.parse] throws [FrameException] or [CrcException], the
/// invalid frame bytes are discarded and the buffer continues scanning for
/// the next valid frame. This prevents a single corrupt frame from blocking
/// all subsequent data.
class FrameBuffer {
  /// Internal byte buffer.
  final List<int> _buffer = [];

  /// Maximum buffer size to prevent memory exhaustion.
  final int maxBufferSize;

  /// The SOF (Start of Frame) delimiter to look for.
  final int sofDelimiter;

  /// The frame parser used to validate extracted frames.
  final FrameParser _parser;

  /// Creates a [FrameBuffer] with the given configuration.
  FrameBuffer({
    this.maxBufferSize = 4096,
    this.sofDelimiter = ProtocolConstants.sof,
    FrameParser? parser,
  }) : _parser = parser ?? FrameParser();

  /// The current number of bytes in the buffer.
  int get length => _buffer.length;

  /// Whether the buffer is empty.
  bool get isEmpty => _buffer.isEmpty;

  /// Adds incoming bytes and attempts to extract complete frames.
  ///
  /// Returns a list of successfully parsed [DeviceFrame] objects.
  /// Invalid frames (SOF/EOF/length/CRC errors) are discarded and the
  /// buffer continues scanning for the next valid frame.
  List<DeviceFrame> addBytes(List<int> bytes) {
    _buffer.addAll(bytes);

    // Trim buffer if it exceeds max size (discard oldest bytes)
    if (_buffer.length > maxBufferSize) {
      final excess = _buffer.length - maxBufferSize;
      _buffer.removeRange(0, excess);
    }

    return _extractFrames();
  }

  /// Attempts to extract complete frames from the buffer.
  List<DeviceFrame> _extractFrames() {
    final frames = <DeviceFrame>[];

    while (_buffer.length >= ProtocolConstants.minFrameSize) {
      // Step 1: Find SOF delimiter
      final sofIndex = _buffer.indexOf(sofDelimiter);
      if (sofIndex == -1) {
        // No SOF found anywhere — clear the entire buffer
        _buffer.clear();
        break;
      }

      // Discard bytes before SOF
      if (sofIndex > 0) {
        _buffer.removeRange(0, sofIndex);
      }

      // Step 2: Need at least the full header to read LEN
      // Header = SOF(1) + VER(1) + PROD(2) + ADDR(4) + OP(1) + CMD(1) + SEQ(1) + FLAGS(1) + LEN(2) = 14 bytes
      const headerBytes = 14;
      if (_buffer.length < headerBytes) {
        // Not enough for header yet — wait for more data
        break;
      }

      // Step 3: Read LEN_H/LEN_L (big-endian) at indices 12-13
      final declaredPayloadLength = EndianUtils.bytesToUint16BE(_buffer, 12);

      // Step 4: Calculate total frame size
      // headerBytes(14) + payload + CRC(2) + EOF(1)
      final totalFrameSize = headerBytes + declaredPayloadLength + ProtocolConstants.trailerSize;

      // Step 5: Check if we have the full frame
      if (_buffer.length < totalFrameSize) {
        // Not enough bytes yet — wait for more data
        break;
      }

      // Step 6: Extract the complete frame bytes
      final frameBytes = _buffer.sublist(0, totalFrameSize);
      _buffer.removeRange(0, totalFrameSize);

      // Step 7: Parse with FrameParser
      try {
        final frame = _parser.parse(frameBytes);
        frames.add(frame);
        // Continue loop to check for more frames
      } on FrameException {
        // Invalid frame structure — discard and continue scanning
        // The frame bytes have already been removed from _buffer
        continue;
      } on CrcException {
        // CRC mismatch — discard and continue scanning
        continue;
      }
    }

    return frames;
  }

  /// Clears all buffered data.
  void clear() {
    _buffer.clear();
  }
}