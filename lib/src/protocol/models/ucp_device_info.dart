import 'decoded_tlv.dart';

/// Official `device_info` payload decoded from TLVs.
class UcpDeviceInfo {
  final String? deviceName;
  final String? firmwareVersion;
  final int? uptimeSeconds;
  final int? counter;
  final int? firmwareLevel;
  final int? firmwareStage;
  final int? firmwareState;
  final String? date;
  final String? time;
  final String? aunkurId;
  final String? hardwareVersion;
  final int? totalTests;
  final String? sdStorage;
  final double? batteryCurrent;
  final double? batteryVoltage;
  final int? batterySoc;
  final int? testRemaining;
  final double? batteryTemperature;
  final double? ambientTemperature;
  final double? ambientHumidity;
  final String? errorMessage;
  final int? deviceIndex;
  final int? reportTestNumber;
  final List<DecodedTlv> tlvs;

  const UcpDeviceInfo({
    this.deviceName,
    this.firmwareVersion,
    this.uptimeSeconds,
    this.counter,
    this.firmwareLevel,
    this.firmwareStage,
    this.firmwareState,
    this.date,
    this.time,
    this.aunkurId,
    this.hardwareVersion,
    this.totalTests,
    this.sdStorage,
    this.batteryCurrent,
    this.batteryVoltage,
    this.batterySoc,
    this.testRemaining,
    this.batteryTemperature,
    this.ambientTemperature,
    this.ambientHumidity,
    this.errorMessage,
    this.deviceIndex,
    this.reportTestNumber,
    this.tlvs = const <DecodedTlv>[],
  });
}
