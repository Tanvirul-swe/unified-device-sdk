/// Core protocol constants used across the device communication protocol.
///
/// Frame format:
///   SOF(1) VER(1) PRODUCT(2) ADDR(4) OP(1) CMD(1) SEQ(1) FLAGS(1)
///   LEN_H(1) LEN_L(1) PAYLOAD(n) CRC_H(1) CRC_L(1) EOF(1)
///
/// Header = 10 bytes (SOF through LEN_L)
/// Trailer = 3 bytes (CRC_H + CRC_L + EOF)
class ProtocolConstants {
  ProtocolConstants._();

  // ---- Frame Delimiters ----
  static const int sof = 0xDD;
  static const int eof = 0x77;

  // ---- Protocol Versions ----
  static const int protocolVersion1 = 0x01;
  static const int currentProtocolVersion = protocolVersion1;

  // ---- Frame Sizes ----
  /// Header size: SOF(1) + VER(1) + PRODUCT(2) + ADDR(4) + OP(1) + CMD(1) + SEQ(1) + FLAGS(1) + LEN(2)
  static const int headerSize = 10;

  /// CRC-16 checksum size in bytes.
  static const int crcSize = 2;

  /// Trailer size: CRC(2) + EOF(1)
  static const int trailerSize = 3;

  /// Minimum valid frame size: header + trailer (no payload).
  static const int minFrameSize = headerSize + trailerSize;

  /// Maximum payload size in bytes.
  /// TODO: Confirm with hardware team — this may change based on BLE MTU.
  static const int maxPayloadSize = 512;

  /// Maximum frame size: header + max payload + trailer.
  static const int maxFrameSize = headerSize + maxPayloadSize + trailerSize;

  // ---- Timeouts ----
  /// Default timeout for a single command-response cycle.
  static const Duration defaultCommandTimeout = Duration(seconds: 5);

  /// Default timeout for establishing a BLE connection.
  static const Duration defaultConnectTimeout = Duration(seconds: 10);

  /// Interval between heartbeat frames when idle.
  /// TODO: Confirm with hardware team — value may change.
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// Timeout for waiting for a heartbeat response.
  /// TODO: Confirm with hardware team — value may change.
  static const Duration heartbeatTimeout = Duration(seconds: 10);

  // ---- Sequence Numbers ----
  /// Maximum sequence number before wrapping.
  static const int maxSequenceNumber = 255;

  /// Initial sequence number.
  static const int initialSequenceNumber = 0;
}