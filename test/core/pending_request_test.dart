import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('PendingRequest', () {
    test('stores official UCP routing metadata', () {
      final request = PendingRequest(
        sequence: 5,
        productId: ProductIds.aunkurUcp1,
        profileId: ProfileIds.dummyM2m,
        sourceAddress: UcpAddresses.software,
        destinationAddress: UcpAddresses.device,
        commandId: SystemCommandIds.deviceInfo,
        op: OperationCodes.req,
        commandClass: CommandClasses.system,
        flags: 0,
      );

      expect(request.productId, ProductIds.aunkurUcp1);
      expect(request.profileId, ProfileIds.dummyM2m);
      expect(request.sourceAddress, UcpAddresses.software);
      expect(request.destinationAddress, UcpAddresses.device);
      expect(request.commandClass, CommandClasses.system);
    });

    test('ack timeout callback still works', () async {
      final request = PendingRequest(
        sequence: 7,
        productId: ProductIds.aunkurUcp1,
        destinationAddress: UcpAddresses.device,
        commandId: SystemCommandIds.time,
        op: OperationCodes.req,
        options: const CommandOptions(ackTimeout: Duration(milliseconds: 10)),
      );

      var timedOut = false;
      request.startAckTimeout((pending) {
        timedOut = identical(pending, request);
      });

      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(timedOut, isTrue);
    });
  });
}
