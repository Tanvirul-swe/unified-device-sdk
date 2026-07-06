import '../../protocol/constants/protocol_constants.dart';

/// Generates monotonically increasing 16-bit sequence numbers for UCP frames.
class SequenceGenerator {
  final int maxValue;
  int _current;
  final int _startValue;

  SequenceGenerator({
    this.maxValue = ProtocolConstants.maxSequenceNumber,
    int startValue = ProtocolConstants.initialSequenceNumber,
  }) : _current = startValue,
       _startValue = startValue {
    if (startValue < 0 || startValue > maxValue) {
      throw ArgumentError(
        'startValue must be between 0 and $maxValue, but got $startValue',
      );
    }
  }

  int get current => _current;

  int next() {
    final value = _current;
    _current = _current >= maxValue ? 0 : _current + 1;
    return value;
  }

  void reset() {
    _current = _startValue;
  }
}
