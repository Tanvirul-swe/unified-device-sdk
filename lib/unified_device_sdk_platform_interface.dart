import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'unified_device_sdk_method_channel.dart';

abstract class UnifiedDeviceSdkPlatform extends PlatformInterface {
  /// Constructs a UnifiedDeviceSdkPlatform.
  UnifiedDeviceSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static UnifiedDeviceSdkPlatform _instance = MethodChannelUnifiedDeviceSdk();

  /// The default instance of [UnifiedDeviceSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelUnifiedDeviceSdk].
  static UnifiedDeviceSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [UnifiedDeviceSdkPlatform] when
  /// they register themselves.
  static set instance(UnifiedDeviceSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
