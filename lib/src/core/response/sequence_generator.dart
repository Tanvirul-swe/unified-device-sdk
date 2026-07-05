/// Generates monotonically increasing sequence numbers for frame tracking.
///
/// Default range is 1-255 inclusive. The sequence never returns 0 by default.
/// After reaching 255, the next value rolls over to 1.
///
/// ## Usage
///
/// ```dart
/// final seq = SequenceGenerator();
/// print(seq.next()); // 1
/// print(seq.next()); // 2
/// seq.reset();
/// print(seq.next()); // 1
/// ```
///
/// ## Custom Start Value
///
/// If you need to start from a different value, pass [startValue]. The range
/// is always 1..[maxValue]. [startValue] must be within that range.
class SequenceGenerator {
  /// The maximum sequence value before rollover (default: 255).
  final int maxValue;

  /// The current sequence value (the next value that will be returned).
  int _current;

  /// The value to return after [reset].
  final int _startValue;

  /// Creates a [SequenceGenerator].
  ///
  /// [maxValue] defaults to 255.
  /// [startValue] defaults to 1 and must be between 1 and [maxValue] inclusive.
  /// Throws [ArgumentError] if [startValue] is outside 1..[maxValue].
  SequenceGenerator({this.maxValue = 255, int startValue = 1})
      : _current = startValue,
        _startValue = startValue {
    if (startValue < 1 || startValue > maxValue) {
      throw ArgumentError(
        'startValue must be between 1 and $maxValue, but got $startValue',
      );
    }
  }

  /// The current sequence number (the next value that [next] will return).
  int get current => _current;

  /// Returns the next sequence number and advances the counter.
  ///
  /// The first call returns [startValue] (default: 1).
  /// After reaching [maxValue] (default: 255), the next call returns 1.
  /// The sequence never returns 0.
  int next() {
    final value = _current;
    _current = (_current % maxValue) + 1;
    return value;
  }

  /// Resets the sequence back to the original [startValue] (default: 1).
  void reset() {
    _current = _startValue;
  }
}