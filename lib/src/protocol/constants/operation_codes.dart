/// Operation codes (OP) used in the frame header.
///
/// The OP field in the frame determines the type of operation being performed.
/// These are distinct from command IDs (CMD field) which identify specific
/// commands within an operation type.
class OperationCodes {
  OperationCodes._();

  /// Read data from the device.
  /// Used with CMD to specify which data to read.
  static const int read = 0xA5;

  /// Write data to the device.
  /// Used with CMD to specify which parameter to write.
  static const int write = 0x5A;

  /// Trigger an action on the device.
  /// Used with CMD to specify which action to perform.
  static const int action = 0xC3;

  /// Acknowledgment — device confirms successful receipt.
  static const int ack = 0x06;

  /// Negative acknowledgment — device reports an error.
  /// Payload contains the error code.
  static const int nack = 0x15;

  /// Asynchronous event from the device (not in response to a command).
  /// Payload contains event data.
  static const int event = 0xE0;

  /// Bulk data transfer from the device.
  /// Used for streaming or large data sets.
  static const int data = 0xD0;
}