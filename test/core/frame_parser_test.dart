import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

List<int> _hex(String value) {
  return value.split(' ').map((byte) => int.parse(byte, radix: 16)).toList();
}

void main() {
  group('UcpFrameParser', () {
    late UcpFrameParser parser;

    setUp(() {
      parser = UcpFrameParser();
    });

    test('parses official start_test request and decodes TLVs', () {
      final frame = parser.parse(
        _hex(
          'DD 01 01 01 01 10 01 03 01 00 07 00 00 30 '
          '30 00 0A 41 47 45 4E 54 2D 44 45 4D 4F '
          '31 00 0A 46 41 52 4D 45 52 2D 30 30 31 '
          '32 00 07 46 49 45 4C 44 2D 41 '
          '33 00 09 54 45 53 54 2D 30 30 30 31 '
          '62 DA 77',
        ),
      );

      expect(frame.productId, ProductIds.aunkurUcp1);
      expect(frame.profileId, ProfileIds.dummyM2m);
      expect(frame.sourceAddress, UcpAddresses.software);
      expect(frame.destinationAddress, UcpAddresses.device);
      expect(frame.op, OperationCodes.req);
      expect(frame.commandClass, CommandClasses.measurement);
      expect(frame.commandId, MeasurementCommandIds.startTest);
      expect(frame.sequence, 7);
      expect(frame.payloadLength, 48);
      expect(frame.tlvs, hasLength(4));
      expect(frame.tlvs[0].type, TlvTypes.agentId);
      expect(frame.tlvs[0].asAsciiString(), 'AGENT-DEMO');
      expect(frame.tlvs[3].type, TlvTypes.testId);
      expect(frame.tlvs[3].asAsciiString(), 'TEST-0001');
    });

    test('parses empty-payload system request', () {
      final frame = parser.parse(
        _hex('DD 01 01 01 01 10 01 01 02 00 03 00 00 00 65 C6 77'),
      );

      expect(frame.commandClass, CommandClasses.system);
      expect(frame.commandId, SystemCommandIds.deviceInfo);
      expect(frame.sequence, 3);
      expect(frame.payload, isEmpty);
      expect(frame.tlvs, isEmpty);
    });

    test('preserves raw payload when it is not valid TLV', () {
      final builder = UcpFrameBuilder();
      final bytes = builder.build(
        version: 1,
        productId: ProductIds.aunkurUcp1,
        op: OperationCodes.nack,
        commandClass: CommandClasses.system,
        commandId: SystemCommandIds.deviceInfo,
        sequence: 9,
        flags: 1,
        payload: const [0x7F],
      );

      final frame = parser.parse(bytes);
      expect(frame.payload, [0x7F]);
      expect(frame.tlvs, isEmpty);
    });

    test('throws on CRC mismatch', () {
      final bytes = _hex('DD 01 01 01 01 10 01 01 02 00 03 00 00 00 65 C6 77');
      bytes[bytes.length - 2] ^= 0xFF;

      expect(() => parser.parse(bytes), throwsA(isA<CrcException>()));
    });
  });
}
