import '../../core/bytes/byte_reader.dart';
import '../../core/errors/protocol_exception.dart';
import '../models/battery_info.dart';
import '../models/device_info.dart';
import '../models/device_status.dart';
import '../models/firmware_info.dart';
import '../models/protocol_version.dart';
import 'response_parser.dart';

/// Optional parsers for shared/common response payloads.
class CommonResponseParser {
  final ResponseParser<DeviceInfo> deviceInfo = const DeviceInfoParser();
  final ResponseParser<FirmwareInfo> firmwareInfo = const FirmwareInfoParser();
  final ResponseParser<BatteryInfo> batteryInfo = const BatteryInfoParser();
  final ResponseParser<ProtocolVersion> protocolVersion =
      const ProtocolVersionParser();
  final ResponseParser<DeviceStatus> deviceStatus = const DeviceStatusParser();

  DeviceInfo parseDeviceInfo(List<int> payload) => deviceInfo.parse(payload);
  FirmwareInfo parseFirmwareInfo(List<int> payload) => firmwareInfo.parse(payload);
  BatteryInfo parseBatteryInfo(List<int> payload) => batteryInfo.parse(payload);
  ProtocolVersion parseProtocolVersion(List<int> payload) =>
      protocolVersion.parse(payload);
  DeviceStatus parseDeviceStatus(List<int> payload) => deviceStatus.parse(payload);
}

/// Conservative parser for a generic device info payload.
///
/// Current assumed layout:
/// `productId:u16le hardwareVersion:u16le serial:null-terminated-ascii
///  manufacturer?:null-terminated-ascii model?:null-terminated-ascii`
///
/// TODO: Revisit endianness and string layout once the protocol contract
/// is finalized.
class DeviceInfoParser extends ResponseParser<DeviceInfo> {
  const DeviceInfoParser();

  @override
  DeviceInfo parse(List<int> payload) {
    if (!validateLength(payload, 4)) {
      throw const ProtocolException(
        'Device info payload too short',
        protocolErrorType: ProtocolErrorType.responseParsingFailed,
      );
    }

    final reader = ByteReader(payload);
    final productId = reader.readUint16LE();
    final hardwareVersion = reader.readUint16LE();
    final serialNumber = _readNullTerminatedString(reader);
    final manufacturerName =
        reader.isEof ? '' : _readNullTerminatedString(reader);
    final modelName = reader.isEof ? '' : _readNullTerminatedString(reader);

    return DeviceInfo(
      productId: productId,
      hardwareVersion: hardwareVersion,
      serialNumber: serialNumber,
      manufacturerName: manufacturerName,
      modelName: modelName,
    );
  }
}

/// Conservative parser for a generic firmware info payload.
///
/// Assumed layout:
/// `major:u8 minor:u8 patch:u8 build:u16le versionString?:null-terminated-ascii`
///
/// TODO: Confirm build number endianness and whether `versionString`
/// is always present.
class FirmwareInfoParser extends ResponseParser<FirmwareInfo> {
  const FirmwareInfoParser();

  @override
  FirmwareInfo parse(List<int> payload) {
    if (!validateLength(payload, 5)) {
      throw const ProtocolException(
        'Firmware info payload too short',
        protocolErrorType: ProtocolErrorType.responseParsingFailed,
      );
    }

    final reader = ByteReader(payload);
    final major = reader.readUint8();
    final minor = reader.readUint8();
    final patch = reader.readUint8();
    final buildNumber = reader.readUint16LE();
    final versionString = reader.isEof ? '' : _readNullTerminatedString(reader);

    return FirmwareInfo(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: buildNumber,
      versionString: versionString,
    );
  }
}

/// Conservative parser for a generic battery payload.
///
/// Assumed layout:
/// `level:u8 voltage?:u16le status?:u8`
///
/// TODO: Confirm whether voltage is in millivolts and whether status flags are:
/// bit0=`charging`, bit1=`low battery`.
class BatteryInfoParser extends ResponseParser<BatteryInfo> {
  const BatteryInfoParser();

  @override
  BatteryInfo parse(List<int> payload) {
    if (!validateLength(payload, 1)) {
      throw const ProtocolException(
        'Battery payload too short',
        protocolErrorType: ProtocolErrorType.responseParsingFailed,
      );
    }

    final reader = ByteReader(payload);
    final level = reader.readUint8();
    final voltage = reader.remaining >= 2 ? reader.readUint16LE() : 0;
    final status = reader.remaining >= 1 ? reader.readUint8() : 0;

    return BatteryInfo(
      level: level,
      voltage: voltage,
      isCharging: (status & 0x01) != 0,
      isLow: (status & 0x02) != 0,
    );
  }
}

/// Conservative parser for protocol version payloads.
class ProtocolVersionParser extends ResponseParser<ProtocolVersion> {
  const ProtocolVersionParser();

  @override
  ProtocolVersion parse(List<int> payload) {
    if (!validateLength(payload, 2)) {
      throw const ProtocolException(
        'Protocol version payload too short',
        protocolErrorType: ProtocolErrorType.responseParsingFailed,
      );
    }

    final reader = ByteReader(payload);
    final major = reader.readUint8();
    final minor = reader.readUint8();
    final patch = reader.remaining >= 1 ? reader.readUint8() : 0;

    return ProtocolVersion(major: major, minor: minor, patch: patch);
  }
}

/// Conservative parser for shared device status payloads.
///
/// TODO: Confirm if all products share this exact layout before depending
/// on it broadly.
class DeviceStatusParser extends ResponseParser<DeviceStatus> {
  const DeviceStatusParser();

  @override
  DeviceStatus parse(List<int> payload) {
    if (!validateLength(payload, 6)) {
      throw const ProtocolException(
        'Device status payload too short',
        protocolErrorType: ProtocolErrorType.responseParsingFailed,
      );
    }

    final reader = ByteReader(payload);
    final mode = reader.readUint8();
    final state = reader.readUint8();
    final uptimeSeconds = reader.readUint32LE();
    final errorCode = reader.remaining >= 1 ? reader.readUint8() : 0;
    final customData = reader.isEof ? <int>[] : reader.readRemainingBytes();

    return DeviceStatus(
      mode: mode,
      state: state,
      uptimeSeconds: uptimeSeconds,
      errorCode: errorCode,
      customData: customData,
    );
  }
}

String _readNullTerminatedString(ByteReader reader) {
  final bytes = <int>[];
  while (!reader.isEof) {
    final byte = reader.readUint8();
    if (byte == 0) {
      break;
    }
    bytes.add(byte);
  }
  return String.fromCharCodes(bytes);
}
