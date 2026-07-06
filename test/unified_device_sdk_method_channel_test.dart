import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelUnifiedDevice', () {
    late MethodChannelUnifiedDevice platform;
    const MethodChannel channel = MethodChannel('unified_device_sdk');

    setUp(() {
      platform = MethodChannelUnifiedDevice();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'getPlatformVersion':
                return '42';
              case 'isBluetoothAvailable':
                return true;
              case 'isBluetoothEnabled':
                return true;
              case 'requestBluetoothPermissions':
                return true;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('getPlatformVersion', () async {
      expect(await platform.getPlatformVersion(), '42');
    });

    test('isBluetoothAvailable', () async {
      expect(await platform.isBluetoothAvailable(), isTrue);
    });

    test('isBluetoothEnabled', () async {
      expect(await platform.isBluetoothEnabled(), isTrue);
    });

    test('requestBluetoothPermissions', () async {
      expect(await platform.requestBluetoothPermissions(), isTrue);
    });
  });
}
