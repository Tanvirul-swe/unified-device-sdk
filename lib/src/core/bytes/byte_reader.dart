import 'endian_utils.dart';

/// Exception thrown when a read operation exceeds the available bytes.
class ByteReaderException implements Exception {
  final String message;
  final int requested;
  final int available;

  const ByteReaderException({
    required this.message,
    required this.requested,
    required this.available,
  });

  @override
  String toString() => 'ByteReaderException: $message';
}

/// A utility class for reading typed values from a byte buffer.
///
/// All read methods advance the internal offset. Multi-byte values are read
/// in big-endian order to match the device protocol specification.
class ByteReader {
  final List<int> _buffer;
  int _offset;

  /// Creates a [ByteReader] from a list of bytes.
  ByteReader(this._buffer, [this._offset = 0]);

  /// The current read offset.
  int get offset => _offset;

  /// The number of bytes remaining to be read.
  int get remaining => _buffer.length - _offset;

  /// The total length of the underlying buffer.
  int get length => _buffer.length;

  /// Whether all bytes have been read (equivalent to `remaining == 0`).
  bool get isEof => _offset >= _buffer.length;

  /// Reads a single unsigned byte (0-255).
  ///
  /// Throws [ByteReaderException] if no bytes are available.
  int readUint8() {
    _assertAvailable(1);
    return _buffer[_offset++];
  }

  /// Reads a 16-bit unsigned integer in big-endian order.
  ///
  /// Throws [ByteReaderException] if fewer than 2 bytes are available.
  int readUint16BE() {
    _assertAvailable(2);
    final value = EndianUtils.bytesToUint16BE(_buffer, _offset);
    _offset += 2;
    return value;
  }

  /// Reads a 16-bit unsigned integer in little-endian order.
  ///
  /// Throws [ByteReaderException] if fewer than 2 bytes are available.
  int readUint16LE() {
    _assertAvailable(2);
    final value = EndianUtils.bytesToUint16LE(_buffer, _offset);
    _offset += 2;
    return value;
  }

  /// Reads a 32-bit unsigned integer in big-endian order.
  ///
  /// Throws [ByteReaderException] if fewer than 4 bytes are available.
  int readUint32BE() {
    _assertAvailable(4);
    final value = EndianUtils.bytesToUint32BE(_buffer, _offset);
    _offset += 4;
    return value;
  }

  /// Reads a 32-bit unsigned integer in little-endian order.
  ///
  /// Throws [ByteReaderException] if fewer than 4 bytes are available.
  int readUint32LE() {
    _assertAvailable(4);
    final value = EndianUtils.bytesToUint32LE(_buffer, _offset);
    _offset += 4;
    return value;
  }

  /// Reads exactly [count] bytes and returns them as a list.
  ///
  /// Throws [ByteReaderException] if fewer than [count] bytes are available.
  List<int> readBytes(int count) {
    _assertAvailable(count);
    final bytes = _buffer.sublist(_offset, _offset + count);
    _offset += count;
    return bytes;
  }

  /// Reads all remaining bytes.
  List<int> readRemainingBytes() {
    return readBytes(remaining);
  }

  /// Resets the reader to the beginning of the buffer.
  void reset() {
    _offset = 0;
  }

  /// Asserts that at least [count] bytes are available to read.
  ///
  /// Throws [ByteReaderException] if insufficient bytes remain.
  void _assertAvailable(int count) {
    if (remaining < count) {
      throw ByteReaderException(
        message: 'Insufficient bytes: need $count but only $remaining remaining',
        requested: count,
        available: remaining,
      );
    }
  }
}
