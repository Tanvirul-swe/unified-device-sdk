import '../frame/device_frame.dart';

/// Generic asynchronous event model derived from EVENT frames.
class DeviceEvent {
  /// Sequence number from the event frame.
  final int sequence;

  /// Product identifier from the frame header.
  final int productId;

  /// Command identifier from the frame header.
  final int commandId;

  /// Optional event code when the payload shape supports one.
  final int? eventCode;

  /// Raw event payload bytes.
  final List<int> payload;

  /// Source frame used to derive this event.
  final DeviceFrame? sourceFrame;

  /// Timestamp when the event model was created.
  final DateTime receivedAt;

  DeviceEvent({
    required this.sequence,
    required this.productId,
    required this.commandId,
    this.eventCode,
    required List<int> payload,
    this.sourceFrame,
    DateTime? receivedAt,
  })  : payload = List<int>.unmodifiable(payload),
        receivedAt = receivedAt ?? DateTime.now();

  /// Creates a [DeviceEvent] from a parsed frame.
  ///
  /// If [inferEventCodeFromPayload] is true and the payload is non-empty,
  /// [eventCode] is set to the first payload byte.
  factory DeviceEvent.fromFrame(
    DeviceFrame frame, {
    bool inferEventCodeFromPayload = false,
    DateTime? receivedAt,
  }) {
    return DeviceEvent(
      sequence: frame.sequence,
      productId: frame.productId,
      commandId: frame.commandId,
      eventCode: inferEventCodeFromPayload && frame.payload.isNotEmpty
          ? frame.payload.first
          : null,
      payload: frame.payload,
      sourceFrame: frame,
      receivedAt: receivedAt,
    );
  }

  /// Legacy alias retained for older call sites.
  int get eventType => commandId;

  @override
  String toString() {
    return 'DeviceEvent('
        'sequence: $sequence, '
        'commandId: 0x${commandId.toRadixString(16).toUpperCase()}, '
        'eventCode: ${eventCode == null ? 'n/a' : '0x${eventCode!.toRadixString(16).toUpperCase()}'}, '
        'payload: [${payload.length} bytes])';
  }
}
