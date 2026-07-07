/// Controls how much communication detail the SDK emits.
enum UcpLogMode {
  /// Emits no communication logs.
  off,

  /// Emits only errors and failure conditions.
  errorOnly,

  /// Emits BLE/UCP lifecycle and command result summaries.
  basic,

  /// Emits decoded packet summaries in addition to basic logs.
  verbose,

  /// Emits verbose logs plus raw bytes and full TLV details.
  raw,
}
