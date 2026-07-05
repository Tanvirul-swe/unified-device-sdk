/// Represents a command to be sent to a device.
class DeviceCommand {
  /// The command identifier.
  final int commandId;

  /// The command payload bytes.
  final List<int> payload;

  /// Command flags.
  final int flags;

  /// Whether this command expects a response.
  final bool expectsResponse;

  /// Optional timeout for this command.
  final Duration? timeout;

  /// Creates a [DeviceCommand] with the given parameters.
  const DeviceCommand({
    required this.commandId,
    this.payload = const [],
    this.flags = 0,
    this.expectsResponse = true,
    this.timeout,
  });

  /// Creates a copy of this command with the given fields replaced.
  DeviceCommand copyWith({
    int? commandId,
    List<int>? payload,
    int? flags,
    bool? expectsResponse,
    Duration? timeout,
  }) {
    return DeviceCommand(
      commandId: commandId ?? this.commandId,
      payload: payload ?? this.payload,
      flags: flags ?? this.flags,
      expectsResponse: expectsResponse ?? this.expectsResponse,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  String toString() {
    return 'DeviceCommand(id: 0x${commandId.toRadixString(16).toUpperCase().padLeft(2, '0')}, '
        'payload: [${payload.length} bytes], '
        'expectsResponse: $expectsResponse)';
  }
}