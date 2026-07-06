import 'dart:typed_data';

/// Codec for encoding and decoding payload data.
///
/// Provides methods for serializing and deserializing payload data
/// in the device protocol format.
class PayloadCodec {
  /// Encodes a list of integers into a byte payload.
  static List<int> encodeIntList(List<int> values) {
    final bytes = <int>[];
    for (final value in values) {
      if (value >= -128 && value <= 127) {
        bytes.add(0x01); // Type: int8
        bytes.add(value & 0xFF);
      } else if (value >= -32768 && value <= 32767) {
        bytes.add(0x02); // Type: int16
        bytes.addAll([(value >> 8) & 0xFF, value & 0xFF]);
      } else {
        bytes.add(0x04); // Type: int32
        bytes.addAll([
          (value >> 24) & 0xFF,
          (value >> 16) & 0xFF,
          (value >> 8) & 0xFF,
          value & 0xFF,
        ]);
      }
    }
    return bytes;
  }

  /// Encodes a string into a byte payload.
  static List<int> encodeString(String value) {
    final encoded = _encodeUtf8(value);
    final length = encoded.length;
    return [length & 0xFF, (length >> 8) & 0xFF, ...encoded];
  }

  /// Encodes a boolean as a single byte.
  static List<int> encodeBool(bool value) {
    return [value ? 0x01 : 0x00];
  }

  /// Encodes a float as 4 bytes (IEEE 754).
  static List<int> encodeFloat(double value) {
    final bytes = ByteData(4)..setFloat32(0, value);
    return bytes.buffer.asUint8List().toList();
  }

  /// Decodes a list of integers from a byte payload.
  static List<int> decodeIntList(List<int> bytes) {
    final values = <int>[];
    var offset = 0;
    while (offset < bytes.length) {
      if (offset >= bytes.length) break;
      final type = bytes[offset];
      offset++;
      switch (type) {
        case 0x01: // int8
          if (offset >= bytes.length) break;
          values.add(bytes[offset].toSigned(8));
          offset += 1;
          break;
        case 0x02: // int16
          if (offset + 2 > bytes.length) break;
          values.add(((bytes[offset] << 8) | bytes[offset + 1]).toSigned(16));
          offset += 2;
          break;
        case 0x04: // int32
          if (offset + 4 > bytes.length) break;
          values.add(
            ((bytes[offset] << 24) |
                    (bytes[offset + 1] << 16) |
                    (bytes[offset + 2] << 8) |
                    bytes[offset + 3])
                .toSigned(32),
          );
          offset += 4;
          break;
        default:
          // Unknown type, skip
          offset++;
          break;
      }
    }
    return values;
  }

  /// Decodes a string from a byte payload.
  static String decodeString(List<int> bytes) {
    if (bytes.length < 2) return '';
    final length = bytes[0] | (bytes[1] << 8);
    if (bytes.length < 2 + length) return '';
    return _decodeUtf8(bytes.sublist(2, 2 + length));
  }

  /// Decodes a boolean from a single byte.
  static bool decodeBool(List<int> bytes) {
    if (bytes.isEmpty) return false;
    return bytes[0] != 0;
  }

  /// Decodes a float from 4 bytes (IEEE 754).
  static double decodeFloat(List<int> bytes) {
    if (bytes.length < 4) return 0.0;
    return ByteData.sublistView(Uint8List.fromList(bytes)).getFloat32(0);
  }

  /// Simple UTF-8 encoding (handles ASCII range).
  static List<int> _encodeUtf8(String value) {
    return value.codeUnits;
  }

  /// Simple UTF-8 decoding (handles ASCII range).
  static String _decodeUtf8(List<int> bytes) {
    return String.fromCharCodes(bytes);
  }
}
