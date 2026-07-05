import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

import '../mocks/fake_transport.dart';

Future<void> _drainQueue() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('UnifiedDeviceClient', () {
    late FakeTransport transport;
    late UnifiedDeviceClient client;
    late FrameBuilder frameBuilder;
    late FrameParser frameParser;

    setUp(() {
      transport = FakeTransport();
      client = UnifiedDeviceClient(
        UnifiedDeviceClientConfig(transport: transport),
      );
      frameBuilder = FrameBuilder();
      frameParser = FrameParser();
    });

    tearDown(() async {
      await client.dispose();
      await transport.dispose();
    });

    test('exposes discoveredDevices and connectionState streams', () async {
      final devices = <DiscoveredDevice>[];
      final states = <DeviceConnectionState>[];

      final deviceSub = client.discoveredDevices.listen(devices.add);
      final stateSub = client.connectionState.listen(states.add);
      addTearDown(deviceSub.cancel);
      addTearDown(stateSub.cancel);

      transport.simulateDeviceDiscovered(
        DiscoveredDevice(deviceId: 'dev-1', rssi: -50),
      );
      transport.simulateConnectionState(
        DeviceConnectionState.connected,
        deviceId: 'dev-1',
      );
      await _drainQueue();

      expect(devices.single.deviceId, 'dev-1');
      expect(states, contains(DeviceConnectionState.connected));
      expect(client.isConnected, isTrue);
    });

    test('sendCommand validates inputs', () async {
      transport.simulateConnectionState(
        DeviceConnectionState.connected,
        deviceId: 'dev-1',
      );
      await _drainQueue();

      expect(
        () => client.sendCommand(
          productId: -1,
          op: OperationCodes.read,
          commandId: 1,
        ),
        throwsArgumentError,
      );
    });

    test('sendCommand sends via manager and emits frames/events', () async {
      transport.simulateConnectionState(
        DeviceConnectionState.connected,
        deviceId: 'dev-1',
      );
      await _drainQueue();

      final frames = <DeviceFrame>[];
      final events = <DeviceEvent>[];
      final frameSub = client.frames.listen(frames.add);
      final eventSub = client.events.listen(events.add);
      addTearDown(frameSub.cancel);
      addTearDown(eventSub.cancel);

      final future = client.sendCommand(
        productId: 0x1001,
        op: OperationCodes.read,
        commandId: 0x21,
      );

      final outbound = frameParser.parse(transport.writtenData.single);

      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0x1001,
          address: 0,
          op: OperationCodes.event,
          commandId: 0x55,
          sequence: 1,
          flags: 0,
          payload: const [0xAB, 0xCD],
        ),
      );

      transport.simulateIncomingData(
        frameBuilder.build(
          version: 1,
          productId: 0x1001,
          address: 0,
          op: OperationCodes.ack,
          commandId: 0x21,
          sequence: outbound.sequence,
          flags: 0,
        ),
      );

      final response = await future;
      await _drainQueue();

      expect(response.sequence, outbound.sequence);
      expect(frames, isNotEmpty);
      expect(events.single.commandId, 0x55);
    });

    test('sendFrame writes prebuilt frame', () async {
      transport.simulateConnectionState(
        DeviceConnectionState.connected,
        deviceId: 'dev-1',
      );
      await _drainQueue();

      final frame = DeviceFrame(
        version: 1,
        productId: 0x1001,
        address: 0,
        op: OperationCodes.write,
        commandId: 0x41,
        sequence: 9,
        flags: 0,
        payload: const [0x01, 0x02],
        crc: 0,
      );

      await client.sendFrame(frame);

      expect(transport.writtenData, hasLength(1));
      final written = frameParser.parse(transport.writtenData.single);
      expect(written.commandId, 0x41);
      expect(written.sequence, 9);
    });
  });
}
