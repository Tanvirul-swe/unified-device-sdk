import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

List<int> _hex(String value) {
  return value.split(' ').map((byte) => int.parse(byte, radix: 16)).toList();
}

void main() {
  group('UcpFrameBuilder', () {
    late UcpFrameBuilder builder;

    setUp(() {
      builder = UcpFrameBuilder();
    });

    test('builds bt_transport_open request exactly', () {
      final bytes = builder.build(
        version: 0x01,
        productId: ProductIds.aunkurUcp1,
        profileId: ProfileIds.dummyM2m,
        sourceAddress: UcpAddresses.software,
        destinationAddress: UcpAddresses.device,
        op: OperationCodes.req,
        commandClass: CommandClasses.session,
        commandId: SessionCommandIds.btTransportOpen,
        sequence: 0x0001,
        flags: 0x00,
        tlvs: [
          Tlv(
            type: TlvTypes.btTransportClientName,
            value: 'ELAB_UCP_CLIENT'.codeUnits,
          ),
        ],
      );

      expect(
        bytes,
        _hex(
          'DD 01 01 01 01 10 01 02 04 00 01 00 00 12 '
          '04 00 0F 45 4C 41 42 5F 55 43 50 5F 43 4C 49 45 4E 54 '
          'B6 37 77',
        ),
      );
    });

    test('builds device_info request exactly', () {
      final bytes = builder.build(
        version: 0x01,
        productId: ProductIds.aunkurUcp1,
        profileId: ProfileIds.dummyM2m,
        sourceAddress: UcpAddresses.software,
        destinationAddress: UcpAddresses.device,
        op: OperationCodes.req,
        commandClass: CommandClasses.system,
        commandId: SystemCommandIds.deviceInfo,
        sequence: 0x0003,
        flags: 0x00,
      );

      expect(bytes, _hex('DD 01 01 01 01 10 01 01 02 00 03 00 00 00 65 C6 77'));
    });

    test('builds time read request exactly', () {
      final bytes = builder.build(
        version: 0x01,
        productId: ProductIds.aunkurUcp1,
        profileId: ProfileIds.dummyM2m,
        sourceAddress: UcpAddresses.software,
        destinationAddress: UcpAddresses.device,
        op: OperationCodes.req,
        commandClass: CommandClasses.system,
        commandId: SystemCommandIds.time,
        sequence: 0x0004,
        flags: 0x00,
      );

      expect(bytes, _hex('DD 01 01 01 01 10 01 01 01 00 04 00 00 00 FA 0B 77'));
    });

    test('builds start_test request with official TLVs exactly', () {
      final bytes = builder.build(
        version: 0x01,
        productId: ProductIds.aunkurUcp1,
        profileId: ProfileIds.dummyM2m,
        sourceAddress: UcpAddresses.software,
        destinationAddress: UcpAddresses.device,
        op: OperationCodes.req,
        commandClass: CommandClasses.measurement,
        commandId: MeasurementCommandIds.startTest,
        sequence: 0x0007,
        flags: 0x00,
        tlvs: [
          Tlv(type: TlvTypes.agentId, value: 'AGENT-DEMO'.codeUnits),
          Tlv(type: TlvTypes.farmerId, value: 'FARMER-001'.codeUnits),
          Tlv(type: TlvTypes.fieldId, value: 'FIELD-A'.codeUnits),
          Tlv(type: TlvTypes.testId, value: 'TEST-0001'.codeUnits),
        ],
      );

      expect(
        bytes,
        _hex(
          'DD 01 01 01 01 10 01 03 01 00 07 00 00 30 '
          '30 00 0A 41 47 45 4E 54 2D 44 45 4D 4F '
          '31 00 0A 46 41 52 4D 45 52 2D 30 30 31 '
          '32 00 07 46 49 45 4C 44 2D 41 '
          '33 00 09 54 45 53 54 2D 30 30 30 31 '
          '62 DA 77',
        ),
      );
    });
  });
}
