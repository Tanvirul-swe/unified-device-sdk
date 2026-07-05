import '../../core/bytes/byte_reader.dart';
import '../../core/bytes/byte_writer.dart';

/// Builder for constructing generic protocol payloads.
class PayloadBuilder {
  ByteWriter _writer = ByteWriter();

  /// Returns the current payload bytes.
  List<int> build() => _writer.toBytes();

  /// Writes a uint8.
  PayloadBuilder writeUint8(int value) {
    _writer.writeUint8(value);
    return this;
  }

  /// Writes a uint16 in big-endian order.
  PayloadBuilder writeUint16BE(int value) {
    _writer.writeUint16BE(value);
    return this;
  }

  /// Writes a uint32 in big-endian order.
  PayloadBuilder writeUint32BE(int value) {
    _writer.writeUint32BE(value);
    return this;
  }

  /// Writes raw bytes.
  PayloadBuilder writeBytes(List<int> bytes) {
    _writer.writeBytes(bytes);
    return this;
  }

  /// Writes an ASCII string.
  PayloadBuilder writeAscii(String value) {
    _writer.writeAscii(value);
    return this;
  }

  /// Writes a UTF-8 string.
  PayloadBuilder writeUtf8(String value) {
    _writer.writeUtf8(value);
    return this;
  }

  /// Resets the builder to an empty payload.
  void reset() {
    _writer = ByteWriter();
  }

  // Legacy aliases retained for existing tests/call sites.
  PayloadBuilder addUint8(int value) => writeUint8(value);
  PayloadBuilder addUint16BE(int value) => writeUint16BE(value);
  PayloadBuilder addUint32BE(int value) => writeUint32BE(value);
  PayloadBuilder addBytes(List<int> bytes) => writeBytes(bytes);

  /// Writes a uint16 length prefix followed by UTF-8 bytes.
  PayloadBuilder addLengthPrefixedString(String value) {
    final bytes = value.codeUnits;
    writeUint16BE(bytes.length);
    writeBytes(bytes);
    return this;
  }

  /// Writes ASCII bytes followed by a null terminator.
  PayloadBuilder addNullTerminatedString(String value) {
    writeAscii(value);
    writeUint8(0);
    return this;
  }

  /// Writes ASCII bytes padded or truncated to [length].
  PayloadBuilder addFixedString(String value, int length) {
    final bytes = value.codeUnits;
    if (bytes.length >= length) {
      writeBytes(bytes.sublist(0, length));
      return this;
    }

    writeBytes(bytes);
    for (var i = bytes.length; i < length; i++) {
      writeUint8(0);
    }
    return this;
  }

  /// Appends zero padding bytes.
  PayloadBuilder addPadding(int count) {
    for (var i = 0; i < count; i++) {
      writeUint8(0);
    }
    return this;
  }
}

/// Reader helper for parsing generic payloads.
class PayloadReader {
  final ByteReader _reader;

  PayloadReader(List<int> bytes) : _reader = ByteReader(bytes);

  int readUint8() => _reader.readUint8();
  int readUint16BE() => _reader.readUint16BE();
  int readUint32BE() => _reader.readUint32BE();
  List<int> readBytes(int count) => _reader.readBytes(count);

  String readLengthPrefixedString() {
    final length = _reader.readUint16BE();
    return String.fromCharCodes(_reader.readBytes(length));
  }

  String readNullTerminatedString() {
    final buffer = <int>[];
    while (!_reader.isEof) {
      final byte = _reader.readUint8();
      if (byte == 0) {
        break;
      }
      buffer.add(byte);
    }
    return String.fromCharCodes(buffer);
  }

  String readFixedString(int length) {
    final bytes = _reader.readBytes(length);
    return String.fromCharCodes(bytes.where((b) => b != 0));
  }

  List<int> readRemainingBytes() => _reader.readRemainingBytes();
  int get offset => _reader.offset;
  bool get hasMore => !_reader.isEof;
}
