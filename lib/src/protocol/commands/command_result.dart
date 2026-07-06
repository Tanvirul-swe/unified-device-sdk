import '../models/device_info.dart';
import '../models/firmware_info.dart';
import '../models/battery_info.dart';
import '../models/device_status.dart';
import '../models/protocol_version.dart';

/// Represents the result of executing a device command.
sealed class CommandResult {
  const CommandResult();
}

/// Result for the Ping command.
class PingResult extends CommandResult {
  final int responseTimeMs;
  const PingResult(this.responseTimeMs);
}

/// Result for the GetDeviceInfo command.
class DeviceInfoResult extends CommandResult {
  final DeviceInfo deviceInfo;
  const DeviceInfoResult(this.deviceInfo);
}

/// Result for the GetFirmwareVersion command.
class FirmwareVersionResult extends CommandResult {
  final FirmwareInfo firmwareInfo;
  const FirmwareVersionResult(this.firmwareInfo);
}

/// Result for the GetBatteryLevel command.
class BatteryLevelResult extends CommandResult {
  final BatteryInfo batteryInfo;
  const BatteryLevelResult(this.batteryInfo);
}

/// Result for the GetDeviceStatus command.
class DeviceStatusResult extends CommandResult {
  final DeviceStatus deviceStatus;
  const DeviceStatusResult(this.deviceStatus);
}

/// Result for the GetProtocolVersion command.
class ProtocolVersionResult extends CommandResult {
  final ProtocolVersion protocolVersion;
  const ProtocolVersionResult(this.protocolVersion);
}

/// Result for a generic command with raw data.
class GenericCommandResult extends CommandResult {
  final List<int> data;
  final int statusCode;
  const GenericCommandResult(this.data, {this.statusCode = 0});
}

/// Result for a command that failed.
class CommandErrorResult extends CommandResult {
  final String message;
  final int? errorCode;
  const CommandErrorResult(this.message, {this.errorCode});
}
