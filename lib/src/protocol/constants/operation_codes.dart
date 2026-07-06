class OperationCodes {
  OperationCodes._();

  static const int req = 0x01;
  static const int ack = 0x02;
  static const int nack = 0x03;
  static const int data = 0x04;
  static const int event = 0x05;
  static const int stream = 0x06;
  static const int heartbeat = 0x08;

  // Legacy aliases retained so existing call sites still compile, but they now
  // encode as the official request opcode.
  static const int read = req;
  static const int write = req;
  static const int action = req;
}
