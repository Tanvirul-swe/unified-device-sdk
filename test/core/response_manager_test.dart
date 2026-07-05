import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

import '../mocks/fake_transport.dart';

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('ResponseManager', () {
    late FakeTransport transport;
    late ResponseManager manager;
    late FrameBuilder frameBuilder;
    late FrameParser frameParser;

    setUp(() {
      transport = FakeTransport();
      manager = ResponseManager(transport: transport);
      frameBuilder = FrameBuilder();
      frameParser = FrameParser();
    });

    tearDown(() async {
      manager.dispose();
      await transport.dispose();
    });

    test('ACK-only success', () async {
      final future = manager.sendCommand(
        commandId: 0x21,
        productId: 0x1001,
        address: 0x01020304,
        op: OperationCodes.read,
      );

      expect(transport.writtenData, hasLength(1));
      final requestFrame = frameParser.parse(transport.writtenData.single);

      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0x1001,
          address: 0x01020304,
          op: OperationCodes.ack,
          commandId: 0x21,
          sequence: requestFrame.sequence,
          flags: 0,
          payload: const [],
        ),
      );

      final response = await future;
      expect(response.sequence, requestFrame.sequence);
      expect(response.commandId, 0x21);
      expect(response.op, OperationCodes.ack);
      expect(manager.pendingCount, 0);
    });

    test('ACK then DATA success', () async {
      final future = manager.sendCommand(
        commandId: 0x31,
        op: OperationCodes.read,
        options: const CommandOptions(
          waitForAck: true,
          waitForData: true,
          ackTimeout: Duration(seconds: 1),
          dataTimeout: Duration(seconds: 1),
        ),
      );

      final requestFrame = frameParser.parse(transport.writtenData.single);
      var completed = false;
      unawaited(future.then((_) => completed = true));

      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.ack,
          commandId: 0x31,
          sequence: requestFrame.sequence,
          flags: 0,
          payload: const [],
        ),
      );
      await _flushMicrotasks();
      expect(completed, isFalse);

      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.data,
          commandId: 0x31,
          sequence: requestFrame.sequence,
          flags: 0,
          payload: const [0xAA, 0xBB],
        ),
      );

      final response = await future;
      expect(response.op, OperationCodes.data);
      expect(response.payload, [0xAA, 0xBB]);
    });

    test('NACK failure', () async {
      final future = manager.sendCommand(
        commandId: 0x41,
        op: OperationCodes.action,
      );

      final requestFrame = frameParser.parse(transport.writtenData.single);
      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.nack,
          commandId: 0x41,
          sequence: requestFrame.sequence,
          flags: 0x01,
          payload: const [0x7F],
        ),
      );

      await expectLater(
        future,
        throwsA(
          isA<ProtocolException>()
              .having((e) => e.protocolErrorType, 'type', ProtocolErrorType.nackReceived)
              .having((e) => e.errorCode, 'errorCode', 0x7F),
        ),
      );
    });

    test('EVENT emission', () async {
      final events = <DeviceEvent>[];
      final subscription = manager.events.listen(events.add);
      addTearDown(subscription.cancel);

      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0x2002,
          address: 0,
          op: OperationCodes.event,
          commandId: 0x77,
          sequence: 1,
          flags: 0,
          payload: const [0xAB, 0xCD],
        ),
      );
      await _flushMicrotasks();

      expect(events, hasLength(1));
      expect(events.single.commandId, 0x77);
      expect(events.single.eventCode, 0xAB);
      expect(events.single.payload, [0xAB, 0xCD]);
    });

    test('timeout waiting for ACK', () async {
      final future = manager.sendCommand(
        commandId: 0x51,
        options: const CommandOptions(
          ackTimeout: Duration(milliseconds: 20),
          waitForAck: true,
          waitForData: false,
        ),
      );

      await expectLater(
        future,
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.operation,
            'operation',
            contains('ACK'),
          ),
        ),
      );
    });

    test('timeout waiting for DATA', () async {
      final future = manager.sendCommand(
        commandId: 0x61,
        options: const CommandOptions(
          ackTimeout: Duration(milliseconds: 20),
          dataTimeout: Duration(milliseconds: 20),
          waitForAck: true,
          waitForData: true,
        ),
      );

      final requestFrame = frameParser.parse(transport.writtenData.single);
      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.ack,
          commandId: 0x61,
          sequence: requestFrame.sequence,
          flags: 0,
        ),
      );

      await expectLater(
        future,
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.operation,
            'operation',
            contains('DATA'),
          ),
        ),
      );
    });

    test('disconnect fails pending requests', () async {
      final future = manager.sendCommand(commandId: 0x71);
      transport.simulateConnectionState(DeviceConnectionState.disconnected);

      await expectLater(
        future,
        throwsA(isA<TransportException>()),
      );
    });

    test('sequence matching keeps requests isolated', () async {
      final first = manager.sendCommand(
        commandId: 0x81,
        options: const CommandOptions(waitForAck: true, waitForData: false),
      );
      final second = manager.sendCommand(
        commandId: 0x82,
        options: const CommandOptions(waitForAck: true, waitForData: false),
      );

      expect(transport.writtenData, hasLength(2));
      final firstFrame = frameParser.parse(transport.writtenData[0]);
      final secondFrame = frameParser.parse(transport.writtenData[1]);

      var firstCompleted = false;
      unawaited(first.then((_) => firstCompleted = true));

      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.ack,
          commandId: 0x82,
          sequence: secondFrame.sequence,
          flags: 0,
        ),
      );
      await _flushMicrotasks();

      final secondResponse = await second;
      expect(secondResponse.sequence, secondFrame.sequence);
      expect(firstCompleted, isFalse);

      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0,
          address: 0,
          op: OperationCodes.ack,
          commandId: 0x81,
          sequence: firstFrame.sequence,
          flags: 0,
        ),
      );

      final firstResponse = await first;
      expect(firstResponse.sequence, firstFrame.sequence);
    });
  });
}
