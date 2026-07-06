import '../frame/device_frame.dart';
import '../../protocol/constants/command_classes.dart';
import '../../protocol/constants/profile_ids.dart';
import '../../protocol/constants/ucp_addresses.dart';

/// Generic asynchronous event model derived from EVENT frames.
class DeviceEvent {
  /// Sequence number from the event frame.
  final int sequence;

  /// Product identifier from the frame header.
  final int productId;

  final int profileId;
  final int sourceAddress;
  final int destinationAddress;

  /// Command identifier from the frame header.
  final int commandId;

  final int commandClass;

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
    this.profileId = ProfileIds.defaultProfile,
    this.sourceAddress = UcpAddresses.defaultSource,
    int? destinationAddress,
    required this.commandId,
    this.commandClass = CommandClasses.system,
    this.eventCode,
    required List<int> payload,
    this.sourceFrame,
    DateTime? receivedAt,
  }) : destinationAddress =
           destinationAddress ?? UcpAddresses.defaultDestination,
       payload = List<int>.unmodifiable(payload),
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
      profileId: frame.profileId,
      sourceAddress: frame.sourceAddress,
      destinationAddress: frame.destinationAddress,
      commandId: frame.commandId,
      commandClass: frame.commandClass,
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
