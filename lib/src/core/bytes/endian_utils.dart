/// Utility class for endianness conversion, byte manipulation, and hex formatting.
class EndianUtils {
  EndianUtils._();

  /// Converts a 16-bit unsigned integer to bytes in big-endian order.
  ///
  /// Throws [ArgumentError] if [value] is outside the uint16 range (0-65535).
  static List<int> uint16ToBytesBE(int value) {
    _validateUint16(value);
    return [(value >> 8) & 0xFF, value & 0xFF];
  }

  /// Converts a 32-bit unsigned integer to bytes in big-endian order.
  ///
  /// Throws [ArgumentError] if [value] is outside the uint32 range (0-4294967295).
  static List<int> uint32ToBytesBE(int value) {
    _validateUint32(value);
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Converts a 64-bit unsigned integer to bytes in big-endian order.
  ///
  /// Throws [ArgumentError] if [value] is outside the uint64 range.
  static List<int> uint64ToBytesBE(int value) {
    _validateUint64(value);
    return [
      (value >> 56) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Reads a 16-bit unsigned integer from [bytes] at [offset] in big-endian order.
  ///
  /// Throws [RangeError] if there are fewer than 2 bytes available from [offset].
  static int bytesToUint16BE(List<int> bytes, [int offset = 0]) {
    _assertAvailable(bytes, offset, 2);
    return (bytes[offset] << 8) | (bytes[offset + 1]);
  }

  /// Reads a 16-bit unsigned integer from [bytes] at [offset] in little-endian order.
  ///
  /// Throws [RangeError] if there are fewer than 2 bytes available from [offset].
  static int bytesToUint16LE(List<int> bytes, [int offset = 0]) {
    _assertAvailable(bytes, offset, 2);
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  /// Reads a 32-bit unsigned integer from [bytes] at [offset] in big-endian order.
  ///
  /// Throws [RangeError] if there are fewer than 4 bytes available from [offset].
  static int bytesToUint32BE(List<int> bytes, [int offset = 0]) {
    _assertAvailable(bytes, offset, 4);
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        (bytes[offset + 3]);
  }

  /// Reads a 32-bit unsigned integer from [bytes] at [offset] in little-endian order.
  ///
  /// Throws [RangeError] if there are fewer than 4 bytes available from [offset].
  static int bytesToUint32LE(List<int> bytes, [int offset = 0]) {
    _assertAvailable(bytes, offset, 4);
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  /// Reads a 64-bit unsigned integer from [bytes] at [offset] in big-endian order.
  ///
  /// Throws [RangeError] if there are fewer than 8 bytes available from [offset].
  static int bytesToUint64BE(List<int> bytes, [int offset = 0]) {
    _assertAvailable(bytes, offset, 8);
    return (bytes[offset] << 56) |
        (bytes[offset + 1] << 48) |
        (bytes[offset + 2] << 40) |
        (bytes[offset + 3] << 32) |
        (bytes[offset + 4] << 24) |
        (bytes[offset + 5] << 16) |
        (bytes[offset + 6] << 8) |
        bytes[offset + 7];
  }

  /// Converts a list of bytes to a hexadecimal string.
  ///
  /// Each byte is represented as two uppercase hex characters, separated by spaces.
  /// Example: `[0xAA, 0xBB]` → `"AA BB"`
  static String toHexString(List<int> bytes) {
    return bytes
        .map(
          (b) => _validateUint8Range(
            b,
          ).toRadixString(16).toUpperCase().padLeft(2, '0'),
        )
        .join(' ');
  }

  /// Validates that [value] is in the uint8 range (0-255).
  static int _validateUint8Range(int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError('Value $value is out of uint8 range (0-255)');
    }
    return value;
  }

  /// Validates that [value] is in the uint16 range (0-65535).
  static void _validateUint16(int value) {
    if (value < 0 || value > 65535) {
      throw ArgumentError('Value $value is out of uint16 range (0-65535)');
    }
  }

  /// Validates that [value] is in the uint32 range (0-4294967295).
  static void _validateUint32(int value) {
    if (value < 0 || value > 4294967295) {
      throw ArgumentError('Value $value is out of uint32 range (0-4294967295)');
    }
  }

  /// Validates that [value] is in the uint64 range.
  static void _validateUint64(int value) {
    if (value < 0) {
      throw ArgumentError('Value $value is out of uint64 range');
    }
  }

  /// Asserts that [bytes] has at least [count] bytes starting from [offset].
  static void _assertAvailable(List<int> bytes, int offset, int count) {
    if (offset + count > bytes.length) {
      throw RangeError.range(
        offset + count,
        0,
        bytes.length,
        'bytes',
        'Insufficient bytes: need $count bytes at offset $offset, '
            'but buffer only has ${bytes.length} bytes total',
      );
    }
  }
}
