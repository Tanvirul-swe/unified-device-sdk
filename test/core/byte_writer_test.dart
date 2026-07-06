import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('ByteWriter', () {
    test('writeUint8', () {
      final writer = ByteWriter();
      writer.writeUint8(0x42);
      expect(writer.toBytes(), [0x42]);
      expect(writer.length, 1);
    });

    test('writeUint8 at boundaries', () {
      final writer = ByteWriter();
      writer.writeUint8(0);
      writer.writeUint8(255);
      expect(writer.toBytes(), [0x00, 0xFF]);
    });

    test('writeUint8 throws on negative value', () {
      final writer = ByteWriter();
      expect(() => writer.writeUint8(-1), throwsArgumentError);
    });

    test('writeUint8 throws on value > 255', () {
      final writer = ByteWriter();
      expect(() => writer.writeUint8(256), throwsArgumentError);
    });

    test('writeUint16BE', () {
      final writer = ByteWriter();
      writer.writeUint16BE(0x1234);
      expect(writer.toBytes(), [0x12, 0x34]);
    });

    test('writeUint16BE at boundaries', () {
      final writer = ByteWriter();
      writer.writeUint16BE(0);
      writer.writeUint16BE(65535);
      expect(writer.toBytes(), [0x00, 0x00, 0xFF, 0xFF]);
    });

    test('writeUint16BE throws on negative value', () {
      final writer = ByteWriter();
      expect(() => writer.writeUint16BE(-1), throwsArgumentError);
    });

    test('writeUint16BE throws on value > 65535', () {
      final writer = ByteWriter();
      expect(() => writer.writeUint16BE(65536), throwsArgumentError);
    });

    test('writeUint32BE', () {
      final writer = ByteWriter();
      writer.writeUint32BE(0x12345678);
      expect(writer.toBytes(), [0x12, 0x34, 0x56, 0x78]);
    });

    test('writeUint32BE at boundaries', () {
      final writer = ByteWriter();
      writer.writeUint32BE(0);
      writer.writeUint32BE(4294967295);
      expect(writer.toBytes(), [
        0x00,
        0x00,
        0x00,
        0x00,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
      ]);
    });

    test('writeUint32BE throws on negative value', () {
      final writer = ByteWriter();
      expect(() => writer.writeUint32BE(-1), throwsArgumentError);
    });

    test('writeUint32BE throws on value > 4294967295', () {
      final writer = ByteWriter();
      expect(() => writer.writeUint32BE(4294967296), throwsArgumentError);
    });

    test('writeBytes', () {
      final writer = ByteWriter();
      writer.writeBytes([0x01, 0x02, 0x03]);
      expect(writer.toBytes(), [0x01, 0x02, 0x03]);
    });

    test('writeBytes throws on invalid byte', () {
      final writer = ByteWriter();
      expect(() => writer.writeBytes([0x01, 256, 0x03]), throwsArgumentError);
    });

    test('writeBytes throws on negative byte', () {
      final writer = ByteWriter();
      expect(() => writer.writeBytes([0x01, -1, 0x03]), throwsArgumentError);
    });

    test('writeAscii', () {
      final writer = ByteWriter();
      writer.writeAscii('ABC');
      expect(writer.toBytes(), [0x41, 0x42, 0x43]);
    });

    test('writeAscii throws on non-ASCII character', () {
      final writer = ByteWriter();
      expect(() => writer.writeAscii('A\u00E9C'), throwsArgumentError);
    });

    test('writeUtf8', () {
      final writer = ByteWriter();
      writer.writeUtf8('AÉC');
      // É is U+00C9, encodes as 0xC3 0x89 in UTF-8
      expect(writer.toBytes(), [0x41, 0xC3, 0x89, 0x43]);
    });

    test('writeUtf8 with ASCII-only string', () {
      final writer = ByteWriter();
      writer.writeUtf8('Hello');
      expect(writer.toBytes(), [0x48, 0x65, 0x6C, 0x6C, 0x6F]);
    });

    test('chaining multiple writes', () {
      final writer = ByteWriter();
      writer.writeUint8(0x01);
      writer.writeUint16BE(0x0203);
      writer.writeUint32BE(0x04050607);
      writer.writeBytes([0x08, 0x09]);
      expect(writer.toBytes(), [
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
      ]);
    });

    test('empty buffer', () {
      final writer = ByteWriter();
      expect(writer.toBytes(), []);
      expect(writer.length, 0);
    });

    test('toBytes returns unmodifiable list', () {
      final writer = ByteWriter();
      writer.writeUint8(0x01);
      final bytes = writer.toBytes();
      // ignore: deprecated_member_use
      expect(() => bytes[0] = 0x02, throwsUnsupportedError);
    });
  });
}
