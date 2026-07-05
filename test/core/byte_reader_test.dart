import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('ByteReader', () {
    test('readUint8', () {
      final reader = ByteReader([0x42]);
      expect(reader.readUint8(), 0x42);
      expect(reader.isEof, isTrue);
    });

    test('readUint8 at boundaries', () {
      final reader = ByteReader([0x00, 0xFF]);
      expect(reader.readUint8(), 0x00);
      expect(reader.readUint8(), 0xFF);
    });

    test('readUint8 throws when past end', () {
      final reader = ByteReader([0x01]);
      reader.readUint8();
      expect(
        () => reader.readUint8(),
        throwsA(isA<ByteReaderException>()),
      );
    });

    test('readUint16BE', () {
      final reader = ByteReader([0x12, 0x34]);
      expect(reader.readUint16BE(), 0x1234);
      expect(reader.isEof, isTrue);
    });

    test('readUint16BE at boundaries', () {
      final reader = ByteReader([0x00, 0x00, 0xFF, 0xFF]);
      expect(reader.readUint16BE(), 0x0000);
      expect(reader.readUint16BE(), 0xFFFF);
    });

    test('readUint16BE throws when insufficient bytes', () {
      final reader = ByteReader([0x01]);
      expect(
        () => reader.readUint16BE(),
        throwsA(isA<ByteReaderException>()),
      );
    });

    test('readUint32BE', () {
      final reader = ByteReader([0x12, 0x34, 0x56, 0x78]);
      expect(reader.readUint32BE(), 0x12345678);
      expect(reader.isEof, isTrue);
    });

    test('readUint32BE at boundaries', () {
      final reader = ByteReader([
        0x00, 0x00, 0x00, 0x00,
        0xFF, 0xFF, 0xFF, 0xFF,
      ]);
      expect(reader.readUint32BE(), 0x00000000);
      expect(reader.readUint32BE(), 0xFFFFFFFF);
    });

    test('readUint32BE throws when insufficient bytes', () {
      final reader = ByteReader([0x01, 0x02, 0x03]);
      expect(
        () => reader.readUint32BE(),
        throwsA(isA<ByteReaderException>()),
      );
    });

    test('readBytes', () {
      final reader = ByteReader([0x01, 0x02, 0x03, 0x04]);
      expect(reader.readBytes(2), [0x01, 0x02]);
      expect(reader.offset, 2);
      expect(reader.readBytes(2), [0x03, 0x04]);
      expect(reader.isEof, isTrue);
    });

    test('readBytes throws when insufficient bytes', () {
      final reader = ByteReader([0x01, 0x02]);
      expect(
        () => reader.readBytes(3),
        throwsA(isA<ByteReaderException>()),
      );
    });

    test('readRemainingBytes', () {
      final reader = ByteReader([0x01, 0x02, 0x03]);
      reader.readUint8(); // consume 1 byte
      expect(reader.readRemainingBytes(), [0x02, 0x03]);
      expect(reader.isEof, isTrue);
    });

    test('remaining property', () {
      final reader = ByteReader([0x01, 0x02, 0x03, 0x04]);
      expect(reader.remaining, 4);
      reader.readBytes(2);
      expect(reader.remaining, 2);
      reader.readBytes(2);
      expect(reader.remaining, 0);
    });

    test('isEof property', () {
      final reader = ByteReader([0x01]);
      expect(reader.isEof, isFalse);
      reader.readUint8();
      expect(reader.isEof, isTrue);
    });

    test('isEof on empty buffer', () {
      final reader = ByteReader([]);
      expect(reader.isEof, isTrue);
    });

    test('reset goes back to beginning', () {
      final reader = ByteReader([0x01, 0x02, 0x03]);
      reader.readUint8();
      expect(reader.offset, 1);
      reader.reset();
      expect(reader.offset, 0);
      expect(reader.readUint8(), 0x01);
    });

    test('sequential read of mixed types', () {
      final reader = ByteReader([0x01, 0x12, 0x34, 0xAA, 0xBB, 0xCC, 0xDD]);
      expect(reader.readUint8(), 0x01);
      expect(reader.readUint16BE(), 0x1234);
      expect(reader.readUint32BE(), 0xAABBCCDD);
      expect(reader.isEof, isTrue);
    });
  });
}