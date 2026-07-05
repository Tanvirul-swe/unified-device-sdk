import '../../core/response/device_event.dart';
import '../constants/operation_codes.dart';

/// Optional parser for generic EVENT frames.
class EventParser {
  const EventParser();

  /// Returns the event unchanged, while optionally inferring an event code
  /// from the first payload byte when not already present.
  DeviceEvent parse(DeviceEvent event) {
    if (event.sourceFrame?.op case final op? when op != OperationCodes.event) {
      return event;
    }

    if (event.eventCode != null || event.payload.isEmpty) {
      return event;
    }

    return DeviceEvent(
      sequence: event.sequence,
      productId: event.productId,
      commandId: event.commandId,
      eventCode: event.payload.first,
      payload: event.payload,
      sourceFrame: event.sourceFrame,
      receivedAt: event.receivedAt,
    );
  }
}
