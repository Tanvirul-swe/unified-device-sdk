import 'payload_builder.dart';

/// Optional payload helpers for shared/common commands.
class CommonPayloads {
  CommonPayloads._();

  /// Builds the common `setTime` payload.
  ///
  /// TODO: Confirm whether the protocol expects UTC epoch seconds,
  /// local epoch seconds, or a structured date/time payload.
  /// This implementation uses UTC epoch seconds in big-endian order
  /// to stay compact and generic until the contract is finalized.
  static List<int> setTime(DateTime time) {
    final epochSeconds = time.toUtc().millisecondsSinceEpoch ~/ 1000;
    return PayloadBuilder().writeUint32BE(epochSeconds).build();
  }

  /// Legacy alias retained for older call sites.
  static List<int> buildSetTimePayload(DateTime time) => setTime(time);
}
