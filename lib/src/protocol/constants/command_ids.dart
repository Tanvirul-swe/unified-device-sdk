class SystemCommandIds {
  SystemCommandIds._();

  static const int time = 0x01;
  static const int deviceInfo = 0x02;
}

class SessionCommandIds {
  SessionCommandIds._();

  static const int sessionOpenRtcSync = 0x01;
  static const int sessionClose = 0x02;
  static const int heartbeat = 0x03;
  static const int btTransportOpen = 0x04;
}

class MeasurementCommandIds {
  MeasurementCommandIds._();

  static const int startTest = 0x01;
  static const int stopTest = 0x02;
  static const int manTestPermit = 0x03;
}

class ReportCommandIds {
  ReportCommandIds._();

  static const int lastReport = 0x01;
}

class MoistureCommandIds {
  MoistureCommandIds._();

  static const int moistGetOn = 0x01;
  static const int moistGetOff = 0x02;
}

class UiCommandIds {
  UiCommandIds._();

  static const int font = 0x01;
}

class ConnectivityCommandIds {
  ConnectivityCommandIds._();

  static const int cdn = 0x01;
}

class CommandIds {
  CommandIds._();

  static const int systemTime = SystemCommandIds.time;
  static const int systemDeviceInfo = SystemCommandIds.deviceInfo;
  static const int sessionOpenRtcSync = SessionCommandIds.sessionOpenRtcSync;
  static const int sessionClose = SessionCommandIds.sessionClose;
  static const int sessionHeartbeat = SessionCommandIds.heartbeat;
  static const int sessionBtTransportOpen = SessionCommandIds.btTransportOpen;
  static const int measurementStartTest = MeasurementCommandIds.startTest;
  static const int measurementStopTest = MeasurementCommandIds.stopTest;
  static const int measurementManTestPermit =
      MeasurementCommandIds.manTestPermit;
  static const int reportLastReport = ReportCommandIds.lastReport;
  static const int moistureGetOn = MoistureCommandIds.moistGetOn;
  static const int moistureGetOff = MoistureCommandIds.moistGetOff;
  static const int uiFont = UiCommandIds.font;
  static const int connectivityCdn = ConnectivityCommandIds.cdn;
}
