import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  test('library exports are accessible', () {
    // Core - Client
    expect(UnifiedDeviceClient, isA<Type>());
    expect(UnifiedDeviceClientConfig, isA<Type>());
    expect(UnifiedDeviceSession, isA<Type>());

    // Core - Transport
    expect(DeviceTransport, isA<Type>());
    expect(BleTransport, isA<Type>());
    expect(DeviceConnectionState, isA<Type>());
    expect(DiscoveredDevice, isA<Type>());

    // Core - Frame
    expect(DeviceFrame, isA<Type>());
    expect(FrameBuilder, isA<Type>());
    expect(FrameParser, isA<Type>());
    expect(FrameBuffer, isA<Type>());
    expect(FrameValidationResult, isA<Type>());

    // Core - CRC
    expect(Crc16Ccitt, isA<Type>());

    // Core - Response
    expect(ResponseManager, isA<Type>());
    expect(PendingRequest, isA<Type>());
    expect(DeviceResponse, isA<Type>());
    expect(DeviceEvent, isA<Type>());
    expect(SequenceGenerator, isA<Type>());

    // Core - Bytes
    expect(ByteReader, isA<Type>());
    expect(ByteWriter, isA<Type>());
    expect(EndianUtils, isA<Type>());

    // Core - Errors
    expect(UnifiedDeviceException, isA<Type>());
    expect(TransportException, isA<Type>());
    expect(FrameException, isA<Type>());
    expect(CrcException, isA<Type>());
    expect(TimeoutException, isA<Type>());
    expect(ProtocolException, isA<Type>());

    // Protocol - Constants
    expect(ProtocolConstants, isA<Type>());
    expect(BleConstants, isA<Type>());
    expect(OperationCodes, isA<Type>());
    expect(ProtocolFlags, isA<Type>());
    expect(ProductIds, isA<Type>());
    expect(CommonCommandIds, isA<Type>());

    // Protocol - Commands
    expect(DeviceCommand, isA<Type>());
    expect(CommonCommands, isA<Type>());

    // Protocol - Payloads
    expect(PayloadBuilder, isA<Type>());
    expect(PayloadReader, isA<Type>());
    expect(PayloadCodec, isA<Type>());
    expect(CommonPayloads, isA<Type>());

    // Protocol - Parsers
    expect(ResponseParser, isA<Type>());
    expect(CommonResponseParser, isA<Type>());

    // Protocol - Models
    expect(DeviceInfo, isA<Type>());
    expect(FirmwareInfo, isA<Type>());
    expect(BatteryInfo, isA<Type>());
    expect(DeviceStatus, isA<Type>());
    expect(ProtocolVersion, isA<Type>());

    // Platform
    expect(UnifiedDevicePlatform, isA<Type>());
    expect(MethodChannelUnifiedDevice, isA<Type>());
    expect(PlatformEventMapper, isA<Type>());

    // Utils
    expect(UnifiedDeviceLogger, isA<Type>());
    expect(Validation, isA<Type>());
  });
}
