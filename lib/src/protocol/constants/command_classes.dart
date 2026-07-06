class CommandClasses {
  CommandClasses._();

  static const int system = 0x01;
  static const int session = 0x02;
  static const int measurement = 0x03;
  static const int report = 0x04;
  static const int moisture = 0x05;
  static const int ui = 0x06;
  static const int connectivity = 0x07;
  static const int calibration = 0x08;
  static const int configuration = 0x09;
  static const int fileTransfer = 0x0A;

  static bool isValid(int value) => value >= 0x00 && value <= 0xFF;
}
