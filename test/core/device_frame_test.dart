import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('DeviceFrame', () {
    test('creates valid DeviceFrame', () {
      final frame = DeviceFrame(
        version: 1,
        productId: 0x1234,
        address: 0xAABBCCDD,
        op: OperationCodes.read,
        commandId: 0x01,
        sequence: 1,
        flags: 0x00,
        payload: [0x10, 0x20],
        crc: 0x29B1,
      );

      expect(frame.version, 1);
      expect(frame.productId, 0x1234);
      expect(frame.address, 0xAABBCCDD);
      expect(frame.op, OperationCodes.read);
      expect(frame.commandId, 0x01);
      expect(frame.sequence, 1);
      expect(frame.flags, 0x00);
      expect(frame.payload, [0x10, 0x20]);
      expect(frame.crc, 0x29B1);
    });

    test('payloadLength is calculated from payload', () {
      final frame = DeviceFrame(
        version: 1,
        productId: 0,
        address: 0,
        op: OperationCodes.read,
        commandId: 0,
        sequence: 1,
        flags: 0,
        payload: [1, 2, 3, 4],
        crc: 0,
      );

      expect(frame.payloadLength, 4);
    });

    test('payload is defensively protected from mutation', () {
      final payload = [1, 2, 3];
      final frame = DeviceFrame(
        version: 1,
        productId: 0,
        address: 0,
        op: OperationCodes.read,
        commandId: 0,
        sequence: 1,
        flags: 0,
        payload: payload,
        crc: 0,
      );

      payload[0] = 99;
      expect(frame.payload, [1, 2, 3]);
      expect(() => frame.payload[0] = 99, throwsUnsupportedError);
    });

    test('invalid byte values throw ArgumentError', () {
      expect(
        () => DeviceFrame(
          version: 256,
          productId: 0,
          address: 0,
          op: OperationCodes.read,
          commandId: 0,
          sequence: 1,
          flags: 0,
          payload: const [],
          crc: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => DeviceFrame(
          version: 1,
          productId: 0,
          address: 0,
          op: -1,
          commandId: 0,
          sequence: 1,
          flags: 0,
          payload: const [],
          crc: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => DeviceFrame(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.read,
          commandId: 999,
          sequence: 1,
          flags: 0,
          payload: const [],
          crc: 0,
        ),
        throwsArgumentError,
      );
    });

    test('invalid productId, address, and crc throw ArgumentError', () {
      expect(
        () => DeviceFrame(
          version: 1,
          productId: 65536,
          address: 0,
          op: OperationCodes.read,
          commandId: 0,
          sequence: 1,
          flags: 0,
          payload: const [],
          crc: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => DeviceFrame(
          version: 1,
          productId: 0,
          address: 4294967296,
          op: OperationCodes.read,
          commandId: 0,
          sequence: 1,
          flags: 0,
          payload: const [],
          crc: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => DeviceFrame(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.read,
          commandId: 0,
          sequence: 1,
          flags: 0,
          payload: const [],
          crc: 65536,
        ),
        throwsArgumentError,
      );
    });

    test('invalid sequence throws ArgumentError by default', () {
      expect(
        () => DeviceFrame(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.read,
          commandId: 0,
          sequence: 0,
          flags: 0,
          payload: const [],
          crc: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => DeviceFrame(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.read,
          commandId: 0,
          sequence: 256,
          flags: 0,
          payload: const [],
          crc: 0,
        ),
        throwsArgumentError,
      );
    });

    test('custom sequence range allows sequence 0 when configured', () {
      final frame = DeviceFrame(
        version: 1,
        productId: 0,
        address: 0,
        op: OperationCodes.event,
        commandId: 0,
        sequence: 0,
        flags: 0,
        payload: const [],
        crc: 0,
        minSequence: 0,
      );

      expect(frame.sequence, 0);
    });

    test('invalid payload byte throws ArgumentError', () {
      expect(
        () => DeviceFrame(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.read,
          commandId: 0,
          sequence: 1,
          flags: 0,
          payload: const [0, 256],
          crc: 0,
        ),
        throwsArgumentError,
      );
    });

    test('op helper booleans', () {
      DeviceFrame frameWithOp(int op) => DeviceFrame(
            version: 1,
            productId: 0,
            address: 0,
            op: op,
            commandId: 0,
            sequence: 1,
            flags: 0,
            payload: const [],
            crc: 0,
          );

      expect(frameWithOp(OperationCodes.ack).isAck, isTrue);
      expect(frameWithOp(OperationCodes.nack).isNack, isTrue);
      expect(frameWithOp(OperationCodes.event).isEvent, isTrue);
      expect(frameWithOp(OperationCodes.data).isData, isTrue);
      expect(frameWithOp(OperationCodes.read).isRead, isTrue);
      expect(frameWithOp(OperationCodes.write).isWrite, isTrue);
      expect(frameWithOp(OperationCodes.action).isAction, isTrue);
    });

    test('toHexString returns logical frame content in hex', () {
      final frame = DeviceFrame(
        version: 1,
        productId: 0x1234,
        address: 0xAABBCCDD,
        op: OperationCodes.read,
        commandId: 0x01,
        sequence: 1,
        flags: 0,
        payload: const [0x10, 0x20],
        crc: 0x29B1,
      );

      expect(
        frame.toHexString(),
        '01 12 34 AA BB CC DD A5 01 01 00 00 02 10 20 29 B1',
      );
    });

    test('toString includes useful debug fields', () {
      final frame = DeviceFrame(
        version: 1,
        productId: 0x1234,
        address: 0xAABBCCDD,
        op: OperationCodes.read,
        commandId: 0x01,
        sequence: 1,
        flags: 0,
        payload: const [0x10],
        crc: 0x29B1,
      );

      final text = frame.toString();
      expect(text, contains('DeviceFrame'));
      expect(text, contains('product: 0x1234'));
      expect(text, contains('addr: 0xAABBCCDD'));
      expect(text, contains('op: 0xA5'));
      expect(text, contains('cmd: 0x01'));
      expect(text, contains('seq: 1'));
    });
  });
}