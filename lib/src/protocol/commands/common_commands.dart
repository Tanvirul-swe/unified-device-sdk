import 'dart:async';
import 'command_result.dart';
import '../../core/client/unified_device_client.dart';
import '../constants/common_command_ids.dart';
import '../constants/operation_codes.dart';
import '../parsers/common_response_parser.dart';
import '../payloads/common_payloads.dart';

/// Provides convenience methods for common device commands.
class CommonCommands {
  final UnifiedDeviceClient _client;
  final CommonResponseParser _parser;

  /// Creates a [CommonCommands] instance bound to a client.
  CommonCommands(this._client) : _parser = CommonResponseParser();

  /// Pings the device to check if it's responsive.
  Future<PingResult> ping() async {
    final stopwatch = Stopwatch()..start();
    await _client.sendCommand(
      productId: 0,
      op: OperationCodes.action,
      commandId: CommonCommandIds.ping,
    );
    stopwatch.stop();
    return PingResult(stopwatch.elapsedMilliseconds);
  }

  /// Retrieves device information.
  Future<DeviceInfoResult> getDeviceInfo() async {
    final response = await _client.sendCommand(
      productId: 0,
      op: OperationCodes.read,
      commandId: CommonCommandIds.readDeviceInfo,
    );
    return DeviceInfoResult(_parser.parseDeviceInfo(response.payload));
  }

  /// Retrieves firmware version information.
  Future<FirmwareVersionResult> getFirmwareVersion() async {
    final response = await _client.sendCommand(
      productId: 0,
      op: OperationCodes.read,
      commandId: CommonCommandIds.readFirmwareVersion,
    );
    return FirmwareVersionResult(_parser.parseFirmwareInfo(response.payload));
  }

  /// Retrieves battery level information.
  Future<BatteryLevelResult> getBatteryLevel() async {
    final response = await _client.sendCommand(
      productId: 0,
      op: OperationCodes.read,
      commandId: CommonCommandIds.readBattery,
    );
    return BatteryLevelResult(_parser.parseBatteryInfo(response.payload));
  }

  /// Sets the device time using a shared common payload contract.
  Future<GenericCommandResult> setTime(DateTime time) async {
    final response = await _client.sendCommand(
      productId: 0,
      op: OperationCodes.write,
      commandId: CommonCommandIds.setTime,
      payload: CommonPayloads.setTime(time),
    );
    return GenericCommandResult(response.payload, statusCode: response.statusCode);
  }

  /// Sends a custom command with raw payload.
  Future<GenericCommandResult> sendCustomCommand({
    required int commandId,
    List<int> payload = const [],
    Duration? timeout,
  }) async {
    final response = await _client.sendCommand(
      productId: 0,
      op: OperationCodes.action,
      commandId: commandId,
      payload: payload,
      timeout: timeout,
    );
    return GenericCommandResult(response.payload, statusCode: response.statusCode);
  }
}
