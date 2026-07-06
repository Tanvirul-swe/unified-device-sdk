/// Generic command execution options.
class CommandOptions {
  /// Timeout to wait for an ACK/NACK frame.
  final Duration ackTimeout;

  /// Timeout to wait for a DATA frame after ACK, if applicable.
  final Duration dataTimeout;

  /// Whether command execution should wait for an ACK/NACK frame.
  final bool waitForAck;

  /// Whether command execution should wait for a DATA frame.
  final bool waitForData;

  /// Whether a matching EVENT frame may complete the request.
  final bool completeOnEvent;

  const CommandOptions({
    this.ackTimeout = const Duration(seconds: 2),
    this.dataTimeout = const Duration(seconds: 5),
    this.waitForAck = true,
    this.waitForData = false,
    this.completeOnEvent = false,
  });

  CommandOptions copyWith({
    Duration? ackTimeout,
    Duration? dataTimeout,
    bool? waitForAck,
    bool? waitForData,
    bool? completeOnEvent,
  }) {
    return CommandOptions(
      ackTimeout: ackTimeout ?? this.ackTimeout,
      dataTimeout: dataTimeout ?? this.dataTimeout,
      waitForAck: waitForAck ?? this.waitForAck,
      waitForData: waitForData ?? this.waitForData,
      completeOnEvent: completeOnEvent ?? this.completeOnEvent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandOptions &&
          runtimeType == other.runtimeType &&
          ackTimeout == other.ackTimeout &&
          dataTimeout == other.dataTimeout &&
          waitForAck == other.waitForAck &&
          waitForData == other.waitForData &&
          completeOnEvent == other.completeOnEvent;

  @override
  int get hashCode => Object.hash(
    ackTimeout,
    dataTimeout,
    waitForAck,
    waitForData,
    completeOnEvent,
  );
}
