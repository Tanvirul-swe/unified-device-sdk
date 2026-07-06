/// Implements CRC-16/CCITT-style variants with configurable parameters.
class Crc16Ccitt {
  /// The generator polynomial (e.g., 0x1021 for CRC-16-CCITT).
  final int polynomial;

  /// The initial CRC value (e.g., 0xFFFF for CRC-16-CCITT).
  final int initialValue;

  /// The final XOR value applied to the CRC before returning (e.g., 0x0000).
  final int finalXor;

  /// Pre-computed CRC lookup table for fast calculation.
  late final List<int> _table;

  /// Creates a [Crc16Ccitt] instance with the given parameters.
  ///
  /// All values must be in the uint16 range (0-65535).
  /// [polynomial] defaults to 0x1021 (CRC-16-CCITT).
  /// [initialValue] defaults to 0xFFFF.
  /// [finalXor] defaults to 0x0000.
  Crc16Ccitt({
    this.polynomial = 0x1021,
    this.initialValue = 0xFFFF,
    this.finalXor = 0x0000,
  }) {
    _validateUint16(polynomial, 'polynomial');
    _validateUint16(initialValue, 'initialValue');
    _validateUint16(finalXor, 'finalXor');
    _table = _buildTable();
  }

  /// CRC-16/CCITT-FALSE as required by the UCP guide.
  factory Crc16Ccitt.ccittFalse() =>
      Crc16Ccitt(polynomial: 0x1021, initialValue: 0xFFFF, finalXor: 0x0000);

  /// Backward-compatible alias.
  factory Crc16Ccitt.standard() => Crc16Ccitt.ccittFalse();

  /// Backward-compatible alias for legacy call sites.
  factory Crc16Ccitt.false_() => Crc16Ccitt.ccittFalse();

  /// Creates a [Crc16Ccitt] instance matching CRC-16-IBM:
  /// polynomial=0x8005, init=0x0000, finalXor=0x0000.
  factory Crc16Ccitt.ibm() =>
      Crc16Ccitt(polynomial: 0x8005, initialValue: 0x0000, finalXor: 0x0000);

  /// Builds the CRC-16 lookup table for the configured polynomial.
  List<int> _buildTable() {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var crc = i << 8;
      for (var j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ polynomial;
        } else {
          crc = crc << 1;
        }
        crc &= 0xFFFF;
      }
      table[i] = crc;
    }
    return table;
  }

  /// Computes the CRC-16 value for the given [data].
  ///
  /// Returns a uint16 value after applying the configured final XOR.
  int compute(List<int> data) {
    var crc = initialValue;
    for (final byte in data) {
      final tableIndex = ((crc >> 8) ^ byte) & 0xFF;
      crc = ((crc << 8) ^ _table[tableIndex]) & 0xFFFF;
    }
    return crc ^ finalXor;
  }

  /// Computes the CRC-16 and returns it as two big-endian bytes.
  ///
  /// The high byte is at index 0, low byte at index 1.
  /// This is the byte order used in the device frame protocol.
  List<int> computeBytesBE(List<int> data) {
    final crc = compute(data);
    return [(crc >> 8) & 0xFF, crc & 0xFF];
  }

  /// Verifies that the CRC of [data] matches [expectedCrc].
  ///
  /// Returns `true` if the CRC matches, `false` otherwise.
  bool verify(List<int> data, int expectedCrc) {
    final computedCrc = compute(data);
    return computedCrc == expectedCrc;
  }

  /// Appends the CRC-16 value (big-endian) to [data] and returns the result.
  List<int> append(List<int> data) {
    return [...data, ...computeBytesBE(data)];
  }

  /// Validates that [value] is in the uint16 range (0-65535).
  static void _validateUint16(int value, String name) {
    if (value < 0 || value > 65535) {
      throw ArgumentError(
        '$name must be in uint16 range (0-65535), but got $value',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Static convenience methods using the standard CRC-16-CCITT defaults.
  // These match the most common CRC-16-CCITT variant (0x1021, init 0xFFFF).
  // ---------------------------------------------------------------------------

  static final Crc16Ccitt _default = Crc16Ccitt.ccittFalse();

  /// Computes the CRC-16-CCITT for [data] using standard parameters
  /// (polynomial=0x1021, init=0xFFFF, finalXor=0x0000).
  static int computeDefault(List<int> data) => _default.compute(data);

  /// Returns the CRC-16-CCITT as two big-endian bytes using standard parameters.
  static List<int> computeDefaultBytesBE(List<int> data) =>
      _default.computeBytesBE(data);

  /// Verifies [data] against [expectedCrc] using standard parameters.
  static bool verifyDefault(List<int> data, int expectedCrc) =>
      _default.verify(data, expectedCrc);

  /// Appends the CRC-16-CCITT (big-endian) to [data] using standard parameters.
  static List<int> appendDefault(List<int> data) => _default.append(data);
}
