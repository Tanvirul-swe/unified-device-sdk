/// Protocol flags used in the FLAGS field of a device frame.
///
/// Flags provide metadata about the frame, such as success/failure status,
/// encryption, compression, and fragmentation.
class ProtocolFlags {
  ProtocolFlags._();

  // ---- Response Flags ----
  /// Command executed successfully.
  static const int success = 0x00;

  /// Command failed with an error.
  static const int error = 0x01;

  /// Frame is an event (not a response to a command).
  static const int event = 0x02;

  /// Request acknowledgment from the device.
  static const int requestAck = 0x04;

  /// Payload is encrypted.
  /// TODO: Confirm encryption scheme with hardware team.
  static const int encrypted = 0x08;

  /// Payload is compressed.
  /// TODO: Confirm compression algorithm with hardware team.
  static const int compressed = 0x10;

  /// More data follows in subsequent frames (fragmentation).
  static const int moreData = 0x20;

  /// This is a retransmission of a previous frame.
  static const int retransmission = 0x40;

  /// Reserved for future use.
  static const int reserved = 0x80;

  // ---- Status Codes (used in NACK payload) ----
  static const int statusOk = 0x00;
  static const int statusUnknownCommand = 0x01;
  static const int statusInvalidParameter = 0x02;
  static const int statusInvalidState = 0x03;
  static const int statusNotSupported = 0x04;
  static const int statusTimeout = 0x05;
  static const int statusBusy = 0x06;
  static const int statusAuthRequired = 0x07;
  static const int statusAuthFailed = 0x08;
  static const int statusCrcError = 0x09;
  static const int statusBufferFull = 0x0A;
  static const int statusInternalError = 0x0F;

  /// Checks if the given flags indicate a successful response.
  static bool isSuccess(int flags) => (flags & error) == 0;

  /// Checks if the given flags indicate an error.
  static bool isError(int flags) => (flags & error) != 0;

  /// Checks if the given flags indicate an event frame.
  static bool isEvent(int flags) => (flags & event) != 0;

  /// Checks if the given flags indicate an encrypted payload.
  static bool isEncrypted(int flags) => (flags & encrypted) != 0;

  /// Checks if the given flags indicate a compressed payload.
  static bool isCompressed(int flags) => (flags & compressed) != 0;
}
