import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('PayloadBuilder', () {
    test('builds empty payload', () {
      final builder = PayloadBuilder();
      expect(builder.build(), []);
    });

    test('adds uint8', () {
      final payload = PayloadBuilder().addUint8(0x42).build();
      expect(payload, [0x42]);
    });

    test('adds uint16 big-endian', () {
      final payload = PayloadBuilder().addUint16BE(0x1234).build();
      expect(payload, [0x12, 0x34]);
    });

    test('adds uint32 big-endian', () {
      final payload = PayloadBuilder().addUint32BE(0x12345678).build();
      expect(payload, [0x12, 0x34, 0x56, 0x78]);
    });

    test('writes ASCII', () {
      final payload = PayloadBuilder().writeAscii('AB').build();
      expect(payload, [0x41, 0x42]);
    });

    test('writes UTF-8', () {
      final payload = PayloadBuilder().writeUtf8('A€').build();
      expect(payload, [0x41, 0xE2, 0x82, 0xAC]);
    });

    test('adds length-prefixed string', () {
      final payload = PayloadBuilder().addLengthPrefixedString('AB').build();
      expect(payload, [0x00, 0x02, 0x41, 0x42]);
    });

    test('adds null-terminated string', () {
      final payload = PayloadBuilder().addNullTerminatedString('Hi').build();
      expect(payload, [0x48, 0x69, 0x00]);
    });

    test('chains multiple values', () {
      final payload = PayloadBuilder()
          .addUint8(0x01)
          .addUint16BE(0x0203)
          .addUint32BE(0x04050607)
          .build();
      expect(payload, [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]);
    });

    test('reset clears accumulated payload', () {
      final builder = PayloadBuilder()..writeUint8(0x01);
      builder.reset();
      expect(builder.build(), isEmpty);
    });
  });

  group('PayloadReader', () {
    test('reads uint8', () {
      final reader = PayloadReader([0x42]);
      expect(reader.readUint8(), 0x42);
    });

    test('reads uint16 big-endian', () {
      final reader = PayloadReader([0x12, 0x34]);
      expect(reader.readUint16BE(), 0x1234);
    });

    test('reads length-prefixed string', () {
      final reader = PayloadReader([0x00, 0x03, 0x41, 0x42, 0x43]);
      expect(reader.readLengthPrefixedString(), 'ABC');
    });

    test('reads null-terminated string', () {
      final reader = PayloadReader([0x48, 0x69, 0x00]);
      expect(reader.readNullTerminatedString(), 'Hi');
    });

    test('tracks offset', () {
      final reader = PayloadReader([0x01, 0x02, 0x03]);
      expect(reader.offset, 0);
      reader.readUint8();
      expect(reader.offset, 1);
    });

    test('hasMore returns correct value', () {
      final reader = PayloadReader([0x01, 0x02]);
      expect(reader.hasMore, isTrue);
      reader.readBytes(2);
      expect(reader.hasMore, isFalse);
    });
  });

  group('CommonPayloads', () {
    test('setTime encodes official epoch_u64 TLV', () {
      final time = DateTime.utc(2026, 7, 2, 12, 34, 56);
      final payload = CommonPayloads.setTime(time);
      final epochSeconds = time.millisecondsSinceEpoch ~/ 1000;

      expect(payload, [
        TlvTypes.epochU64,
        0x00,
        0x08,
        0x00,
        0x00,
        0x00,
        0x00,
        (epochSeconds >> 24) & 0xFF,
        (epochSeconds >> 16) & 0xFF,
        (epochSeconds >> 8) & 0xFF,
        epochSeconds & 0xFF,
      ]);
    });
  });
}
