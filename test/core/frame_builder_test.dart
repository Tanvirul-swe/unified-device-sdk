import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('FrameBuilder', () {
    late FrameBuilder builder;

    setUp(() {
      builder = FrameBuilder();
    });

    // ---- Empty payload frame ----

    test('builds frame with empty payload', () {
      final bytes = builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0x00,
        sequence: 1,
        flags: 0x00,
      );

      // Minimum frame: SOF(1) + header(9) + LEN(2) + CRC(2) + EOF(1) = 15
      // With empty payload: SOF + 9 header bytes + 2 LEN bytes + 0 payload + 2 CRC + 1 EOF = 15
      // Wait: SOF(1) + VER(1) + PROD(2) + ADDR(4) + OP(1) + CMD(1) + SEQ(1) + FLAGS(1) + LEN(2) = 14 before payload
      // 14 + 0 payload + 2 CRC + 1 EOF = 17
      expect(bytes.length, 17);
      expect(bytes[0], 0xDD); // SOF
      expect(bytes.last, 0x77); // EOF
    });

    test('empty payload frame has correct LEN bytes (0)', () {
      final bytes = builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0x00,
        sequence: 1,
        flags: 0x00,
      );

      // LEN is at indices 12-13 (big-endian)
      expect(bytes[12], 0x00);
      expect(bytes[13], 0x00);
    });

    // ---- Non-empty payload frame ----

    test('builds frame with payload', () {
      final bytes = builder.build(
        version: 1,
        productId: 0x1234,
        address: 0xAABBCCDD,
        op: 0xA5,
        commandId: 0x01,
        sequence: 5,
        flags: 0x00,
        payload: [0x10, 0x20, 0x30],
      );

      expect(bytes[0], 0xDD); // SOF
      expect(bytes[1], 1); // version
      expect(bytes[2], 0x12); // productId high
      expect(bytes[3], 0x34); // productId low
      expect(bytes[4], 0xAA); // address byte 0
      expect(bytes[5], 0xBB); // address byte 1
      expect(bytes[6], 0xCC); // address byte 2
      expect(bytes[7], 0xDD); // address byte 3
      expect(bytes[8], 0xA5); // op
      expect(bytes[9], 0x01); // commandId
      expect(bytes[10], 5); // sequence
      expect(bytes[11], 0x00); // flags
      expect(bytes.last, 0x77); // EOF
    });

    test('non-empty payload has correct LEN bytes', () {
      final bytes = builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0x00,
        sequence: 1,
        flags: 0x00,
        payload: [0x01, 0x02, 0x03],
      );

      // LEN = 3 payload bytes → 0x00 0x03 big-endian
      expect(bytes[12], 0x00);
      expect(bytes[13], 0x03);
    });

    test('payload bytes appear at correct position', () {
      final bytes = builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0x00,
        sequence: 1,
        flags: 0x00,
        payload: [0xAA, 0xBB, 0xCC],
      );

      // Payload starts at index 14 (after 14-byte header: SOF + 9 fields + 2 LEN)
      expect(bytes[14], 0xAA);
      expect(bytes[15], 0xBB);
      expect(bytes[16], 0xCC);
    });

    // ---- CRC ----

    test('CRC bytes are present and big-endian', () {
      final bytes = builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0x00,
        sequence: 1,
        flags: 0x00,
      );

      // CRC is at bytes.length - 3 and bytes.length - 2
      final crcHigh = bytes[bytes.length - 3];
      final crcLow = bytes[bytes.length - 2];
      final crc = (crcHigh << 8) | crcLow;
      expect(crc, greaterThan(0));
      expect(crc, lessThanOrEqualTo(0xFFFF));
    });

    test('CRC is correct for known test vector', () {
      // Build frame with known content, then verify CRC
      final bytes = builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0x00,
        sequence: 1,
        flags: 0x00,
        payload: [0x31, 0x32], // "12"
      );

      // Compute expected CRC over VER through PAYLOAD (indices 1 through 15)
      final crcInput = bytes.sublist(1, bytes.length - 3); // skip SOF, CRC, EOF
      final expectedCrc = Crc16Ccitt.standard().compute(crcInput);

      final crcHigh = bytes[bytes.length - 3];
      final crcLow = bytes[bytes.length - 2];
      final actualCrc = (crcHigh << 8) | crcLow;

      expect(actualCrc, expectedCrc);
    });

    // ---- Build from DeviceFrame ----

    test('buildFromFrame produces same result as build', () {
      final frame = DeviceFrame(
        version: 1,
        productId: 0x1234,
        address: 0xAABBCCDD,
        op: 0xA5,
        commandId: 0x01,
        sequence: 5,
        flags: 0x00,
        payload: [0x10, 0x20],
        crc: 0,
      );

      final fromFrame = builder.buildFromFrame(frame);
      final fromFields = builder.build(
        version: 1,
        productId: 0x1234,
        address: 0xAABBCCDD,
        op: 0xA5,
        commandId: 0x01,
        sequence: 5,
        flags: 0x00,
        payload: [0x10, 0x20],
      );

      expect(fromFrame, fromFields);
    });

    // ---- Invalid values ----

    test('throws on invalid version', () {
      expect(
        () => builder.build(
          version: 256,
          productId: 0,
          address: 0,
          op: 0xA5,
          commandId: 0,
          sequence: 1,
          flags: 0,
        ),
        throwsArgumentError,
      );
    });

    test('throws on invalid productId', () {
      expect(
        () => builder.build(
          version: 1,
          productId: 65536,
          address: 0,
          op: 0xA5,
          commandId: 0,
          sequence: 1,
          flags: 0,
        ),
        throwsArgumentError,
      );
    });

    test('throws on invalid address', () {
      expect(
        () => builder.build(
          version: 1,
          productId: 0,
          address: -1,
          op: 0xA5,
          commandId: 0,
          sequence: 1,
          flags: 0,
        ),
        throwsArgumentError,
      );
    });

    test('throws on invalid op', () {
      expect(
        () => builder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: 256,
          commandId: 0,
          sequence: 1,
          flags: 0,
        ),
        throwsArgumentError,
      );
    });

    test('throws on invalid payload byte', () {
      expect(
        () => builder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: 0xA5,
          commandId: 0,
          sequence: 1,
          flags: 0,
          payload: [0, 256],
        ),
        throwsArgumentError,
      );
    });

    test('throws on payload exceeding 65535 bytes', () {
      final largePayload = List<int>.filled(65536, 0);
      expect(
        () => builder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: 0xA5,
          commandId: 0,
          sequence: 1,
          flags: 0,
          payload: largePayload,
        ),
        throwsArgumentError,
      );
    });

    // ---- Configurable CRC range ----

    test('configurable CRC range affects CRC bytes', () {
      // Builder with CRC range including SOF (index 0)
      final builderWithSof = FrameBuilder(crcRangeStart: 0);
      final bytesWithSof = builderWithSof.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0,
        sequence: 1,
        flags: 0x00,
      );

      // Default builder excludes SOF
      final bytesWithoutSof = builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0,
        sequence: 1,
        flags: 0x00,
      );

      // CRC should differ because input range includes/excludes SOF
      expect(bytesWithSof[bytesWithSof.length - 3], isNot(bytesWithoutSof[bytesWithoutSof.length - 3]));
    });

    // ---- Configurable CRC instance ----

    test('configurable CRC instance affects frame bytes', () {
      final customCrc = Crc16Ccitt(polynomial: 0x1021, initialValue: 0x0000, finalXor: 0x0000);
      final builderCustom = FrameBuilder(crc: customCrc);

      final bytesCustom = builderCustom.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0,
        sequence: 1,
        flags: 0x00,
      );

      final bytesDefault = builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0,
        sequence: 1,
        flags: 0x00,
      );

      // Different init → different CRC
      expect(bytesCustom, isNot(bytesDefault));
    });
  });
}