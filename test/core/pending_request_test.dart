import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('PendingRequest', () {
    test('exposes command metadata and future', () {
      final request = PendingRequest(
        sequence: 5,
        productId: 0x1001,
        address: 0x01020304,
        commandId: 0x22,
        op: OperationCodes.read,
        flags: 0x80,
        payload: [0x01, 0x02],
      );

      expect(request.sequence, 5);
      expect(request.productId, 0x1001);
      expect(request.address, 0x01020304);
      expect(request.commandId, 0x22);
      expect(request.op, OperationCodes.read);
      expect(request.flags, 0x80);
      expect(request.payload, [0x01, 0x02]);
      expect(request.future, isA<Future<DeviceResponse>>());
    });

    test('supports ack timeout handling', () async {
      final request = PendingRequest(
        sequence: 7,
        productId: 0,
        address: 0,
        commandId: 1,
        op: OperationCodes.write,
        options: const CommandOptions(
          ackTimeout: Duration(milliseconds: 10),
        ),
      );

      var timedOut = false;
      request.startAckTimeout((pending) {
        timedOut = identical(pending, request);
      });

      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(timedOut, isTrue);
      expect(request.isCompleted, isFalse);
    });

    test('complete cancels timers and resolves future', () async {
      final request = PendingRequest(
        sequence: 9,
        productId: 0,
        address: 0,
        commandId: 2,
        op: OperationCodes.action,
      );
      request.startTimeout((_) {
        fail('timeout should have been cancelled');
      });

      request.complete(
        DeviceResponse.success(
          sequence: 9,
          commandId: 2,
          payload: [0x55],
        ),
      );

      final response = await request.future;
      expect(response.sequence, 9);
      expect(response.payload, [0x55]);
      expect(request.isCompleted, isTrue);
    });
  });

  group('CommandOptions', () {
    test('copyWith overrides selected values', () {
      const options = CommandOptions();
      final updated = options.copyWith(
        ackTimeout: const Duration(seconds: 1),
        waitForData: true,
      );

      expect(updated.ackTimeout, const Duration(seconds: 1));
      expect(updated.dataTimeout, options.dataTimeout);
      expect(updated.waitForAck, isTrue);
      expect(updated.waitForData, isTrue);
    });
  });
}
