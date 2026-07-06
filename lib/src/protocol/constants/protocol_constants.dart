/// Core constants for the official ELAB UCP wire format.
///
/// Frame format:
/// `SOF VER PRODUCT PROFILE SRC DST OP CLASS CMD SEQ_H SEQ_L FLAGS
///  PLEN_H PLEN_L PAYLOAD CRC_H CRC_L EOF`
class ProtocolConstants {
  ProtocolConstants._();

  // ---- Frame Delimiters ----
  static const int sof = 0xDD;
  static const int eof = 0x77;

  static const int protocolVersion1 = 0x01;
  static const int currentProtocolVersion = protocolVersion1;

  // ---- Field offsets ----
  static const int versionOffset = 1;
  static const int productOffset = 2;
  static const int profileOffset = 3;
  static const int sourceOffset = 4;
  static const int destinationOffset = 5;
  static const int operationOffset = 6;
  static const int commandClassOffset = 7;
  static const int commandOffset = 8;
  static const int sequenceOffset = 9;
  static const int flagsOffset = 11;
  static const int payloadLengthOffset = 12;
  static const int payloadOffset = 14;

  // ---- Frame sizes ----
  /// Bytes from SOF through PLEN_L.
  static const int headerSize = 14;
  static const int crcSize = 2;
  static const int trailerSize = 3;
  static const int minimumPayloadLength = 0;
  static const int minFrameSize = headerSize + trailerSize;
  static const int maxPayloadSize = 512;
  static const int maxFrameSize = headerSize + maxPayloadSize + trailerSize;

  // ---- Timeouts ----
  static const Duration defaultCommandTimeout = Duration(seconds: 5);
  static const Duration defaultConnectTimeout = Duration(seconds: 10);
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration heartbeatTimeout = Duration(seconds: 10);

  // ---- Sequence Numbers ----
  static const int maxSequenceNumber = 0xFFFF;
  static const int initialSequenceNumber = 0;
}
