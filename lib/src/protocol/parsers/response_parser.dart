/// Abstract interface for parsing raw payload bytes into a shared model.
abstract class ResponseParser<T> {
  const ResponseParser();

  /// Parses the supplied payload.
  T parse(List<int> payload);

  /// Returns whether the payload has at least [minimumLength] bytes.
  bool validateLength(List<int> payload, int minimumLength) {
    return payload.length >= minimumLength;
  }
}
