import 'dart:convert';
import 'endian_utils.dart';

/// A utility class for building byte buffers by writing typed values.
///
/// All write methods validate their inputs and throw [ArgumentError] if values
/// are out of range. All multi-byte values are written in big-endian order
/// to match the device protocol specification.
class ByteWriter {
  final List<int> _buffer = [];

  /// The current length of the written data in bytes.
  int get length => _buffer.length;

  /// Returns the accumulated bytes as an unmodifiable list.
  List<int> toBytes() => List.unmodifiable(_buffer);

  /// Writes a single unsigned byte (0-255).
  ///
  /// Throws [ArgumentError] if [value] is outside the uint8 range.
  void writeUint8(int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError('uint8 value must be 0-255, but got $value');
    }
    _buffer.add(value);
  }

  /// Writes a 16-bit unsigned integer in big-endian order (0-65535).
  ///
  /// Throws [ArgumentError] if [value] is outside the uint16 range.
  void writeUint16BE(int value) {
    _buffer.addAll(EndianUtils.uint16ToBytesBE(value));
  }

  /// Writes a 32-bit unsigned integer in big-endian order (0-4294967295).
  ///
  /// Throws [ArgumentError] if [value] is outside the uint32 range.
  void writeUint32BE(int value) {
    _buffer.addAll(EndianUtils.uint32ToBytesBE(value));
  }

  /// Writes a 64-bit unsigned integer in big-endian order.
  void writeUint64BE(int value) {
    _buffer.addAll(EndianUtils.uint64ToBytesBE(value));
  }

  /// Writes a list of raw bytes. Each byte must be 0-255.
  ///
  /// Throws [ArgumentError] if any byte is outside the uint8 range.
  void writeBytes(List<int> bytes) {
    for (final byte in bytes) {
      if (byte < 0 || byte > 255) {
        throw ArgumentError('All bytes must be 0-255, but found $byte');
      }
    }
    _buffer.addAll(bytes);
  }

  /// Writes an ASCII string (without null terminator).
  ///
  /// Each character must be in the ASCII range (0-127).
  /// Throws [ArgumentError] if the string contains non-ASCII characters.
  void writeAscii(String value) {
    for (final char in value.codeUnits) {
      if (char > 127) {
        throw ArgumentError(
          'ASCII string contains non-ASCII character: 0x${char.toRadixString(16)}',
        );
      }
    }
    _buffer.addAll(value.codeUnits);
  }

  /// Writes a UTF-8 encoded string (without null terminator).
  ///
  /// Uses standard UTF-8 encoding. For ASCII-only strings, consider
  /// using [writeAscii] for clarity.
  void writeUtf8(String value) {
    _buffer.addAll(utf8.encode(value));
  }
}
