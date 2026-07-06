/// Utility class for validating input parameters.
class Validation {
  Validation._();

  /// Validates that a string is not null or empty.
  static String requireNonEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      throw ArgumentError('$fieldName must not be null or empty');
    }
    return value.trim();
  }

  /// Validates that an integer is within the specified range.
  static int requireInRange(int value, int min, int max, String fieldName) {
    if (value < min || value > max) {
      throw ArgumentError(
        '$fieldName must be between $min and $max (inclusive), but was $value',
      );
    }
    return value;
  }

  /// Validates that a list is not null or empty.
  static List<T> requireNonEmptyList<T>(List<T>? list, String fieldName) {
    if (list == null || list.isEmpty) {
      throw ArgumentError('$fieldName must not be null or empty');
    }
    return list;
  }

  /// Validates that a byte array does not exceed the maximum length.
  static List<int> requireMaxLength(
    List<int> bytes,
    int maxLength,
    String fieldName,
  ) {
    if (bytes.length > maxLength) {
      throw ArgumentError(
        '$fieldName must not exceed $maxLength bytes, but was ${bytes.length} bytes',
      );
    }
    return bytes;
  }

  /// Validates that a duration is positive.
  static Duration requirePositive(Duration? duration, String fieldName) {
    if (duration == null || duration.isNegative) {
      throw ArgumentError('$fieldName must be a positive duration');
    }
    return duration;
  }
}
