import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

/// ASCII "123456789" — the standard CRC check vector.
/// CRC-16-CCITT (0x1021, init 0xFFFF) of these bytes should be 0x29B1.
const _checkVector = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39];

void main() {
  group('Crc16Ccitt (instance)', () {
    late Crc16Ccitt crc;

    setUp(() {
      crc = Crc16Ccitt.standard();
    });

    test('standard CRC-16-CCITT of "123456789" is 0x29B1', () {
      final result = crc.compute(_checkVector);
      expect(result, 0x29B1);
    });

    test('empty data with default init returns initial value XOR finalXor', () {
      // init=0xFFFF, finalXor=0x0000 → 0xFFFF
      final result = crc.compute([]);
      expect(result, 0xFFFF);
    });

    test('result is always in uint16 range', () {
      final result = crc.compute([0xFF, 0xFF, 0xFF, 0xFF]);
      expect(result, greaterThanOrEqualTo(0));
      expect(result, lessThanOrEqualTo(0xFFFF));
    });

    test('verify returns true for correct CRC', () {
      final expected = crc.compute(_checkVector);
      expect(crc.verify(_checkVector, expected), isTrue);
    });

    test('verify returns false for incorrect CRC', () {
      expect(crc.verify(_checkVector, 0x0000), isFalse);
    });

    test('computeBytesBE returns two big-endian bytes', () {
      final bytes = crc.computeBytesBE(_checkVector);
      expect(bytes.length, 2);
      // CRC should be 0x29B1 → bytes [0x29, 0xB1]
      expect(bytes[0], 0x29);
      expect(bytes[1], 0xB1);
    });

    test('computeBytesBE with empty data', () {
      // With init=0xFFFF, finalXor=0x0000 → CRC=0xFFFF → bytes [0xFF, 0xFF]
      final bytes = crc.computeBytesBE([]);
      expect(bytes, [0xFF, 0xFF]);
    });

    test('append adds two big-endian CRC bytes', () {
      final data = [0x01, 0x02, 0x03];
      final result = crc.append(data);
      expect(result.length, 5);
      expect(result[0], 0x01);
      expect(result[1], 0x02);
      expect(result[2], 0x03);
      // Last two bytes are CRC (big-endian)
      expect(result.length, data.length + 2);
    });

    test('is consistent: same data produces same CRC', () {
      final data = List<int>.generate(100, (i) => i & 0xFF);
      final crc1 = crc.compute(data);
      final crc2 = crc.compute(data);
      expect(crc1, crc2);
    });

    test('CRC changes when data changes', () {
      final crc1 = crc.compute([0x01, 0x02, 0x03]);
      final crc2 = crc.compute([0x01, 0x02, 0x04]);
      expect(crc1, isNot(crc2));
    });
  });

  group('Crc16Ccitt (configurable parameters)', () {
    test('custom initial value produces different result', () {
      final standard = Crc16Ccitt.standard();
      final customInit = Crc16Ccitt(polynomial: 0x1021, initialValue: 0x0000, finalXor: 0x0000);

      final resultStandard = standard.compute([0x01, 0x02]);
      final resultCustom = customInit.compute([0x01, 0x02]);
      expect(resultStandard, isNot(resultCustom));
    });

    test('custom final XOR produces different result', () {
      final noXor = Crc16Ccitt(polynomial: 0x1021, initialValue: 0xFFFF, finalXor: 0x0000);
      final xorAll = Crc16Ccitt(polynomial: 0x1021, initialValue: 0xFFFF, finalXor: 0xFFFF);

      final resultNoXor = noXor.compute([0x01, 0x02]);
      final resultXorAll = xorAll.compute([0x01, 0x02]);
      // XOR with 0xFFFF flips all bits
      expect(resultNoXor ^ 0xFFFF, resultXorAll);
    });

    test('CRC-16-IBM with known zero init', () {
      final ibm = Crc16Ccitt.ibm();
      // With init=0x0000, empty data → CRC=0x0000
      final result = ibm.compute([]);
      expect(result, 0x0000);
    });

    test('CRC-16-CCITT-FALSE (init=0x0000)', () {
      final falseCrc = Crc16Ccitt.false_();
      final standard = Crc16Ccitt.standard();
      final resultFalse = falseCrc.compute(_checkVector);
      final resultStd = standard.compute(_checkVector);
      // Different init values produce different results
      expect(resultFalse, isNot(resultStd));
    });

    test('construction with invalid polynomial throws', () {
      expect(
        () => Crc16Ccitt(polynomial: -1),
        throwsArgumentError,
      );
    });

    test('construction with value > uint16 throws', () {
      expect(
        () => Crc16Ccitt(initialValue: 0x10000),
        throwsArgumentError,
      );
    });
  });

  group('Crc16Ccitt (static convenience)', () {
    test('computeDefault matches standard instance', () {
      final instance = Crc16Ccitt.standard();
      expect(
        Crc16Ccitt.computeDefault(_checkVector),
        instance.compute(_checkVector),
      );
    });

    test('computeDefaultBytesBE matches instance', () {
      final instance = Crc16Ccitt.standard();
      expect(
        Crc16Ccitt.computeDefaultBytesBE(_checkVector),
        instance.computeBytesBE(_checkVector),
      );
    });

    test('verifyDefault matches instance', () {
      final expected = Crc16Ccitt.computeDefault(_checkVector);
      expect(Crc16Ccitt.verifyDefault(_checkVector, expected), isTrue);
    });

    test('appendDefault matches instance', () {
      final data = [0x01, 0x02, 0x03];
      final instance = Crc16Ccitt.standard();
      expect(
        Crc16Ccitt.appendDefault(data),
        instance.append(data),
      );
    });
  });
}