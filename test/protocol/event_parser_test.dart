import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('EventParser', () {
    const parser = EventParser();

    test('infers eventCode from payload when missing', () {
      final frame = DeviceFrame(
        version: 1,
        productId: 0x2002,
        address: 0x01000001,
        op: OperationCodes.event,
        commandId: 0x10,
        sequence: 9,
        flags: 0,
        payload: [0xAB, 0x02],
        crc: 0,
      );
      final event = DeviceEvent.fromFrame(frame);

      final parsed = parser.parse(event);

      expect(parsed.sequence, 9);
      expect(parsed.productId, 0x2002);
      expect(parsed.commandId, 0x10);
      expect(parsed.eventCode, 0xAB);
      expect(parsed.sourceFrame, same(frame));
    });

    test('returns event unchanged when eventCode already exists', () {
      final event = DeviceEvent(
        sequence: 1,
        productId: 0x1001,
        commandId: 0x10,
        eventCode: 0x01,
        payload: [0x01, 0x02],
      );

      final parsed = parser.parse(event);

      expect(parsed.eventCode, 0x01);
      expect(parsed.payload, [0x01, 0x02]);
    });
  });
}
