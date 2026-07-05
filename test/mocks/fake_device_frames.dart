import 'package:unified_device_sdk/unified_device_sdk.dart';

/// Provides pre-built fake device frames for testing.
class FakeDeviceFrames {
  static final FrameBuilder _builder = FrameBuilder();

  /// Creates a ping command frame.
  static List<int> pingCommand(int sequenceNumber) {
    return _builder.build(
      version: 1,
      productId: 0,
      address: 0,
      op: 0xA5,
      commandId: 0x00,
      sequence: sequenceNumber,
      flags: 0x00,
    );
  }

  /// Creates a ping response frame.
  static List<int> pingResponse(int sequenceNumber) {
    return _builder.build(
      version: 1,
      productId: 0,
      address: 0,
      op: 0x06, // ACK
      commandId: 0x00,
      sequence: sequenceNumber,
      flags: 0x00,
    );
  }

  /// Creates a get device info command frame.
  static List<int> getDeviceInfoCommand(int sequenceNumber) {
    return _builder.build(
      version: 1,
      productId: 0,
      address: 0,
      op: 0xA5,
      commandId: 0x01,
      sequence: sequenceNumber,
      flags: 0x00,
    );
  }

  /// Creates a get device info response frame with sample data.
  static List<int> getDeviceInfoResponse(int sequenceNumber) {
    return _builder.build(
      version: 1,
      productId: 0x0101,
      address: 0,
      op: 0x06, // ACK
      commandId: 0x01,
      sequence: sequenceNumber,
      flags: 0x00,
      payload: [
        0x01, 0x01, // productId (big-endian)
        0x00, 0x01, // hardwareVersion (big-endian)
        0x53, 0x4E, 0x30, 0x30, 0x31, 0x00, // "SN001\0"
      ],
    );
  }

  /// Creates a get firmware version response frame.
  static List<int> getFirmwareVersionResponse(int sequenceNumber) {
    return _builder.build(
      version: 1,
      productId: 0,
      address: 0,
      op: 0x06, // ACK
      commandId: 0x02,
      sequence: sequenceNumber,
      flags: 0x00,
      payload: [
        0x01, // major
        0x02, // minor
        0x03, // patch
        0x00, 0x2A, // buildNumber (big-endian, 42)
      ],
    );
  }

  /// Creates a get battery level response frame.
  static List<int> getBatteryLevelResponse(int sequenceNumber) {
    return _builder.build(
      version: 1,
      productId: 0,
      address: 0,
      op: 0x06, // ACK
      commandId: 0x03,
      sequence: sequenceNumber,
      flags: 0x00,
      payload: [
        0x5A, // level: 90%
        0x03, 0xE8, // voltage: 1000mV (big-endian)
        0x01, // status: charging
      ],
    );
  }

  /// Creates a NACK response frame.
  static List<int> nackResponse(int sequenceNumber, int errorCode) {
    return _builder.build(
      version: 1,
      productId: 0,
      address: 0,
      op: 0x15, // NACK
      commandId: 0x00,
      sequence: sequenceNumber,
      flags: 0x01, // error flag
      payload: [errorCode],
    );
  }

  /// Creates an event frame.
  static List<int> eventFrame(int eventType, List<int> payload) {
    return _builder.build(
      version: 1,
      productId: 0,
      address: 0,
      op: 0xE0, // EVENT
      commandId: eventType,
      sequence: 0,
      flags: 0x00,
      payload: payload,
    );
  }
}