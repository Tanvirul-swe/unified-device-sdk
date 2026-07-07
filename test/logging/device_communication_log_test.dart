import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('DeviceCommunicationLog', () {
    test('serializes and deserializes with snake_case keys', () {
      const log = DeviceCommunicationLog(
        logId: 'log_1',
        sessionId: 'session_1',
        deviceId: 'AA:BB',
        deviceName: 'Aunkur_UCP1',
        timestamp: 123456789,
        param: <String, dynamic>{
          'event': 'packet_tx',
          'layer': 'ucp',
          'seq': 1,
        },
      );

      final json = log.toJson();

      expect(json, <String, dynamic>{
        'log_id': 'log_1',
        'session_id': 'session_1',
        'device_id': 'AA:BB',
        'device_name': 'Aunkur_UCP1',
        'timestamp': 123456789,
        'param': <String, dynamic>{
          'event': 'packet_tx',
          'layer': 'ucp',
          'seq': 1,
        },
      });
      expect(DeviceCommunicationLog.fromJson(json).toJson(), json);
    });

    test('controller broadcasts and ignores adds after dispose', () async {
      final controller = DeviceCommunicationLogController();
      final received = <DeviceCommunicationLog>[];
      final subscription = controller.stream.listen(received.add);
      addTearDown(subscription.cancel);

      controller.add(
        const DeviceCommunicationLog(
          logId: 'log_1',
          sessionId: 'session_1',
          timestamp: 1,
          param: <String, dynamic>{'event': 'connected'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));

      await controller.dispose();
      controller.add(
        const DeviceCommunicationLog(
          logId: 'log_2',
          sessionId: 'session_1',
          timestamp: 2,
          param: <String, dynamic>{'event': 'ignored'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
    });
  });
}
