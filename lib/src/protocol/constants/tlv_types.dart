import '../models/tlv.dart';

/// TLV types defined by the official dummy guide.
class TlvTypes {
  TlvTypes._();

  static const int epochU64 = 0x01;
  static const int sessionIdU32 = 0x02;
  static const int statusU8 = 0x03;
  static const int textUtf8 = 0x04;
  static const int reasonU8 = 0x05;
  static const int permitU8 = 0x06;
  static const int fontIdU8 = 0x07;
  static const int cdnModeU8 = 0x08;
  static const int moistRawU16 = 0x09;
  static const int moistPercentX100U16 = 0x0A;
  static const int reportIdU32 = 0x0B;
  static const int deviceName = 0x0E;
  static const int fwVersion = 0x0F;
  static const int uptimeU32 = 0x10;
  static const int counterU32 = 0x11;
  static const int eventIdU8 = 0x12;
  static const int disconnectClassU8 = 0x13;
  static const int connectionIdU32 = 0x14;
  static const int sessionStateU8 = 0x15;
  static const int errorCodeU16 = 0x20;
  static const int agentId = 0x30;
  static const int farmerId = 0x31;
  static const int fieldIndex = 0x32;
  static const int fieldTestIndex = 0x33;
  static const int languageU8 = 0x34;
  static const int cdnName = 0x35;
  static const int resultNX100 = 0x40;
  static const int resultPX100 = 0x41;
  static const int resultKX100 = 0x42;
  static const int resultMoistX100 = 0x43;
  static const int resultPhX100 = 0x44;
  static const int resultEcX100 = 0x45;
  static const int fwLevelU8 = 0x52;
  static const int fwStageU8 = 0x53;
  static const int fwStateU8 = 0x54;
  static const int date = 0x55;
  static const int time = 0x56;
  static const int aunkurId = 0x57;
  static const int hwVersion = 0x58;
  static const int totalTestsU32 = 0x59;
  static const int sdStorage = 0x5A;
  static const int batteryCurrentX100 = 0x5B;
  static const int batteryVoltageX100 = 0x5C;
  static const int batterySocU8 = 0x5D;
  static const int testRemainingU16 = 0x5E;
  static const int batteryTemperatureX10 = 0x5F;
  static const int ambientTemperatureX10 = 0x60;
  static const int ambientHumidityX10 = 0x61;
  static const int errorMsg = 0x62;
  static const int deviceIndex = 0x63;
  static const int reportTestNoU32 = 0x64;
  static const int resultTempX100 = 0x65;
  static const int reportError = 0x66;

  // ---- Extended TLV types for future commands ----
  static const int sensorTypeU8 = 0x70;
  static const int calData = 0x71;
  static const int configKeyU16 = 0x72;
  static const int configValue = 0x73;
  static const int exportFormat = 0x74;
  static const int fileName = 0x75;
  static const int fileSizeU32 = 0x76;
  static const int fileOffsetU32 = 0x77;
  static const int fileData = 0x78;
  static const int transferIdU32 = 0x79;

  static const int btTransportClientName = textUtf8;
  static const int fieldId = fieldIndex;
  static const int testId = fieldTestIndex;

  static String nameOf(int type) =>
      _names[type] ??
      '0x${type.toRadixString(16).toUpperCase().padLeft(2, '0')}';

  static Object decodeValue(Tlv tlv) {
    switch (tlv.type) {
      case epochU64:
        return _readUint64(tlv);
      case sessionIdU32:
      case uptimeU32:
      case counterU32:
      case connectionIdU32:
      case reportIdU32:
      case totalTestsU32:
      case reportTestNoU32:
        return _readUint32(tlv);
      case errorCodeU16:
      case moistRawU16:
      case moistPercentX100U16:
      case testRemainingU16:
        return _readUint16(tlv);
      case statusU8:
      case reasonU8:
      case permitU8:
      case fontIdU8:
      case cdnModeU8:
      case eventIdU8:
      case disconnectClassU8:
      case sessionStateU8:
      case languageU8:
      case fwLevelU8:
      case fwStageU8:
      case fwStateU8:
      case batterySocU8:
      case deviceIndex:
        return _readUint8(tlv);
      case resultNX100:
      case resultPX100:
      case resultKX100:
      case resultMoistX100:
      case resultPhX100:
      case resultEcX100:
      case batteryCurrentX100:
      case batteryVoltageX100:
      case resultTempX100:
        return _readUint16(tlv) / 100.0;
      case batteryTemperatureX10:
      case ambientTemperatureX10:
      case ambientHumidityX10:
        return _readUint16(tlv) / 10.0;
      case textUtf8:
      case agentId:
      case farmerId:
      case fieldIndex:
      case fieldTestIndex:
      case deviceName:
      case fwVersion:
      case date:
      case time:
      case aunkurId:
      case hwVersion:
      case sdStorage:
      case errorMsg:
      case reportError:
      case cdnName:
        return tlv.asUtf8String();
      default:
        return tlv.value;
    }
  }

  static const Map<int, String> _names = {
    epochU64: 'epoch_u64',
    sessionIdU32: 'session_id_u32',
    statusU8: 'status_u8',
    textUtf8: 'text_utf8',
    reasonU8: 'reason_u8',
    permitU8: 'permit_u8',
    fontIdU8: 'font_id_u8',
    cdnModeU8: 'cdn_mode_u8',
    moistRawU16: 'moist_raw_u16',
    moistPercentX100U16: 'moist_percent_x100_u16',
    reportIdU32: 'report_id_u32',
    deviceName: 'device_name',
    fwVersion: 'fw_version',
    uptimeU32: 'uptime_u32',
    counterU32: 'counter_u32',
    eventIdU8: 'event_id_u8',
    disconnectClassU8: 'disconnect_class_u8',
    connectionIdU32: 'connection_id_u32',
    sessionStateU8: 'session_state_u8',
    errorCodeU16: 'error_code_u16',
    agentId: 'agent_id',
    farmerId: 'farmer_id',
    fieldIndex: 'field_index',
    fieldTestIndex: 'field_test_index',
    languageU8: 'language_u8',
    cdnName: 'cdn_name',
    resultNX100: 'result_n_x100',
    resultPX100: 'result_p_x100',
    resultKX100: 'result_k_x100',
    resultMoistX100: 'result_moist_x100',
    resultPhX100: 'result_ph_x100',
    resultEcX100: 'result_ec_x100',
    fwLevelU8: 'fw_level_u8',
    fwStageU8: 'fw_stage_u8',
    fwStateU8: 'fw_state_u8',
    date: 'date',
    time: 'time',
    aunkurId: 'aunkur_id',
    hwVersion: 'hw_version',
    totalTestsU32: 'total_tests_u32',
    sdStorage: 'sd_storage',
    batteryCurrentX100: 'battery_current_x100',
    batteryVoltageX100: 'battery_voltage_x100',
    batterySocU8: 'battery_soc_u8',
    testRemainingU16: 'test_remaining_u16',
    batteryTemperatureX10: 'battery_temperature_x10',
    ambientTemperatureX10: 'ambient_temperature_x10',
    ambientHumidityX10: 'ambient_humidity_x10',
    errorMsg: 'error_msg',
    deviceIndex: 'device_index',
    reportTestNoU32: 'report_test_no_u32',
    resultTempX100: 'result_temp_x100',
    reportError: 'report_error',
  };

  static int _readUint8(Tlv tlv) => tlv.value.isEmpty ? 0 : tlv.value.first;

  static int _readUint16(Tlv tlv) {
    if (tlv.value.length < 2) {
      return 0;
    }
    return (tlv.value[0] << 8) | tlv.value[1];
  }

  static int _readUint32(Tlv tlv) {
    if (tlv.value.length < 4) {
      return 0;
    }
    return (tlv.value[0] << 24) |
        (tlv.value[1] << 16) |
        (tlv.value[2] << 8) |
        tlv.value[3];
  }

  static int _readUint64(Tlv tlv) {
    if (tlv.value.length < 8) {
      return 0;
    }
    return (tlv.value[0] << 56) |
        (tlv.value[1] << 48) |
        (tlv.value[2] << 40) |
        (tlv.value[3] << 32) |
        (tlv.value[4] << 24) |
        (tlv.value[5] << 16) |
        (tlv.value[6] << 8) |
        tlv.value[7];
  }
}
