import '../constants/tlv_types.dart';
import 'tlv_builder.dart';

/// Optional payload helpers for shared/common commands.
class CommonPayloads {
  CommonPayloads._();

  /// Builds the common `setTime` payload.
  static List<int> setTime(DateTime time) {
    final epochSeconds = time.toUtc().millisecondsSinceEpoch ~/ 1000;
    return TlvBuilder().addUint64BE(TlvTypes.epochU64, epochSeconds).build();
  }

  /// Legacy alias retained for older call sites.
  static List<int> buildSetTimePayload(DateTime time) => setTime(time);
}
