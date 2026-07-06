import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('EventParser', () {
    const parser = EventParser();

    test('infers eventCode from payload when missing', () {
      final frame = DeviceFrame(
        version: 1,
        productId: ProductIds.aunkurUcp1,
        sourceAddress: UcpAddresses.device,
        destinationAddress: UcpAddresses.software,
        op: OperationCodes.event,
        commandClass: CommandClasses.session,
        commandId: SessionCommandIds.heartbeat,
        sequence: 9,
        flags: 0,
        payload: const [0xAB, 0x02],
        crc: 0,
      );
      final event = DeviceEvent.fromFrame(frame);

      final parsed = parser.parse(event);

      expect(parsed.sequence, 9);
      expect(parsed.productId, ProductIds.aunkurUcp1);
      expect(parsed.commandId, SessionCommandIds.heartbeat);
      expect(parsed.eventCode, 0xAB);
    });
  });
}
