import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('FrameParser', () {
    late FrameParser parser;
    late FrameBuilder builder;

    setUp(() {
      parser = FrameParser();
      builder = FrameBuilder();
    });

    DeviceFrame buildAndParse({
      int version = 1,
      int productId = 0,
      int address = 0,
      int op = 0xA5,
      int commandId = 0,
      int sequence = 1,
      int flags = 0,
      List<int> payload = const [],
    }) {
      final bytes = builder.build(
        version: version,
        productId: productId,
        address: address,
        op: op,
        commandId: commandId,
        sequence: sequence,
        flags: flags,
        payload: payload,
      );
      return parser.parse(bytes);
    }

    // ---- Valid frames ----

    test('parses valid empty payload frame', () {
      final frame = buildAndParse();
      expect(frame.version, 1);
      expect(frame.productId, 0);
      expect(frame.address, 0);
      expect(frame.op, 0xA5);
      expect(frame.commandId, 0);
      expect(frame.sequence, 1);
      expect(frame.flags, 0);
      expect(frame.payload, []);
    });

    test('parses valid non-empty payload frame', () {
      final frame = buildAndParse(
        payload: [0x10, 0x20, 0x30],
      );
      expect(frame.payload, [0x10, 0x20, 0x30]);
      expect(frame.payloadLength, 3);
    });

    test('parses frame with all fields populated', () {
      final frame = buildAndParse(
        version: 2,
        productId: 0x1234,
        address: 0xAABBCCDD,
        op: OperationCodes.write,
        commandId: 0x05,
        sequence: 10,
        flags: 0x04,
        payload: [0x01, 0x02],
      );
      expect(frame.version, 2);
      expect(frame.productId, 0x1234);
      expect(frame.address, 0xAABBCCDD);
      expect(frame.op, OperationCodes.write);
      expect(frame.commandId, 0x05);
      expect(frame.sequence, 10);
      expect(frame.flags, 0x04);
      expect(frame.payload, [0x01, 0x02]);
    });

    // ---- Invalid SOF ----

    test('throws FrameException on invalid SOF', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );
      bytes[0] = 0xBB;

      expect(
        () => parser.parse(bytes),
        throwsA(isA<FrameException>()),
      );
    });

    test('FrameException on invalid SOF has correct error type', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );
      bytes[0] = 0xBB;

      try {
        parser.parse(bytes);
        fail('Expected FrameException');
      } on FrameException catch (e) {
        expect(e.frameErrorType, FrameErrorType.invalidSof);
        expect(e.errorCode, 0xBB);
      }
    });

    // ---- Invalid EOF ----

    test('throws FrameException on invalid EOF', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );
      bytes[bytes.length - 1] = 0x44;

      expect(
        () => parser.parse(bytes),
        throwsA(isA<FrameException>()),
      );
    });

    test('FrameException on invalid EOF has correct error type', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );
      bytes[bytes.length - 1] = 0x44;

      try {
        parser.parse(bytes);
        fail('Expected FrameException');
      } on FrameException catch (e) {
        expect(e.frameErrorType, FrameErrorType.invalidEof);
        expect(e.errorCode, 0x44);
      }
    });

    // ---- Invalid length ----

    test('throws FrameException on frame too short', () {
      expect(
        () => parser.parse([0xDD, 0x01, 0x02]),
        throwsA(isA<FrameException>()),
      );
    });

    test('throws FrameException on frame shorter than minFrameSize', () {
      // 12 bytes is less than minFrameSize (13)
      expect(
        () => parser.parse(List.filled(12, 0x00)),
        throwsA(isA<FrameException>()),
      );
    });

    test('throws FrameException on length mismatch', () {
      // Build a frame, then modify LEN bytes to claim more payload than exists
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );
      // Set LEN to 255 (0x00FF) but no payload bytes actually follow
      bytes[12] = 0x00;
      bytes[13] = 0xFF;

      expect(
        () => parser.parse(bytes),
        throwsA(isA<FrameException>()),
      );
    });

    // ---- Invalid CRC ----

    test('throws CrcException on invalid CRC', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
        payload: [0x01, 0x02],
      );
      // Corrupt a payload byte
      bytes[14] = 0xFF;

      expect(
        () => parser.parse(bytes),
        throwsA(isA<CrcException>()),
      );
    });

    test('CrcException has correct expected/actual values', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
        payload: [0x01],
      );
      bytes[14] = 0xFF; // corrupt payload

      try {
        parser.parse(bytes);
        fail('Expected CrcException');
      } on CrcException catch (e) {
        expect(e.expectedCrc, greaterThan(0));
        expect(e.actualCrc, greaterThan(0));
        expect(e.expectedCrc, isNot(e.actualCrc));
      }
    });

    // ---- Extra/missing bytes ----

    test('throws FrameException on extra trailing bytes', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );
      // Append an extra byte after EOF
      bytes.add(0x00);

      expect(
        () => parser.parse(bytes),
        throwsA(isA<FrameException>()),
      );
    });

    test('throws FrameException on missing bytes', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
        payload: [0x01, 0x02],
      );
      // Truncate last 2 bytes (CRC low + EOF)
      final truncated = bytes.sublist(0, bytes.length - 2);

      expect(
        () => parser.parse(truncated),
        throwsA(isA<FrameException>()),
      );
    });

    // ---- extractPayload ----

    test('extractPayload returns payload from valid frame', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
        payload: [0xAA, 0xBB],
      );
      expect(parser.extractPayload(bytes), [0xAA, 0xBB]);
    });

    test('extractPayload returns null on frame too short', () {
      expect(parser.extractPayload([0xDD, 0x01]), isNull);
    });

    test('extractPayload returns null on invalid SOF', () {
      final bytes = builder.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );
      bytes[0] = 0xBB;
      expect(parser.extractPayload(bytes), isNull);
    });

    // ---- Configurable CRC ----

    test('parser with matching CRC config successfully parses', () {
      final customCrc = Crc16Ccitt(polynomial: 0x1021, initialValue: 0x0000, finalXor: 0x0000);
      final builderCustom = FrameBuilder(crc: customCrc);
      final parserCustom = FrameParser(crc: customCrc);

      final bytes = builderCustom.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );

      final frame = parserCustom.parse(bytes);
      expect(frame.version, 1);
    });

    test('parser with mismatched CRC config throws CrcException', () {
      final builderCrc = Crc16Ccitt(polynomial: 0x1021, initialValue: 0x0000, finalXor: 0x0000);
      final builderCustom = FrameBuilder(crc: builderCrc);

      // Parser uses default CRC (init=0xFFFF) which won't match
      final bytes = builderCustom.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );

      expect(
        () => parser.parse(bytes),
        throwsA(isA<CrcException>()),
      );
    });

    // ---- Configurable CRC range ----

    test('parser with matching CRC range successfully parses', () {
      final builderWithSof = FrameBuilder(crcRangeStart: 0); // include SOF
      final parserWithSof = FrameParser(crcRangeStart: 0);

      final bytes = builderWithSof.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );

      final frame = parserWithSof.parse(bytes);
      expect(frame.version, 1);
    });

    test('parser with mismatched CRC range throws CrcException', () {
      final builderWithSof = FrameBuilder(crcRangeStart: 0); // include SOF

      final bytes = builderWithSof.build(
        version: 1, productId: 0, address: 0,
        op: 0xA5, commandId: 0, sequence: 1, flags: 0,
      );

      // Parser uses default range (exclude SOF) → mismatch
      expect(
        () => parser.parse(bytes),
        throwsA(isA<CrcException>()),
      );
    });
  });
}
