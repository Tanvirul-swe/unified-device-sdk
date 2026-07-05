import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('SequenceGenerator', () {
    test('first sequence is 1', () {
      final gen = SequenceGenerator();
      expect(gen.next(), 1);
    });

    test('increments properly', () {
      final gen = SequenceGenerator();
      expect(gen.next(), 1);
      expect(gen.next(), 2);
      expect(gen.next(), 3);
    });

    test('rolls over after 255 to 1', () {
      final gen = SequenceGenerator();
      // Advance to 255
      for (var i = 0; i < 254; i++) {
        gen.next();
      }
      expect(gen.next(), 255); // 255th call returns 255
      expect(gen.next(), 1); // rolls over to 1
      expect(gen.next(), 2); // continues from 1
    });

    test('never returns 0', () {
      final gen = SequenceGenerator();
      for (var i = 0; i < 1000; i++) {
        final value = gen.next();
        expect(value, greaterThan(0),
            reason: 'sequence should never return 0');
        expect(value, lessThanOrEqualTo(255),
            reason: 'sequence should never exceed 255');
      }
    });

    test('reset returns to startValue (default 1)', () {
      final gen = SequenceGenerator();
      gen.next(); // 1
      gen.next(); // 2
      gen.reset();
      expect(gen.next(), 1);
    });

    test('current reflects next value to be returned', () {
      final gen = SequenceGenerator();
      expect(gen.current, 1);
      gen.next();
      expect(gen.current, 2);
      gen.next();
      expect(gen.current, 3);
    });

    // ---- Custom start value ----

    test('custom startValue works', () {
      final gen = SequenceGenerator(startValue: 5);
      expect(gen.next(), 5);
      expect(gen.next(), 6);
    });

    test('custom startValue with reset', () {
      final gen = SequenceGenerator(startValue: 10);
      gen.next(); // 10
      gen.next(); // 11
      gen.reset();
      expect(gen.next(), 10);
    });

    test('custom maxValue works', () {
      final gen = SequenceGenerator(maxValue: 10, startValue: 8);
      expect(gen.next(), 8);
      expect(gen.next(), 9);
      expect(gen.next(), 10);
      expect(gen.next(), 1); // rolls to 1, not startValue
    });

    // ---- Validation ----

    test('startValue must be >= 1', () {
      expect(
        () => SequenceGenerator(startValue: 0),
        throwsArgumentError,
      );
    });

    test('startValue must be <= maxValue', () {
      expect(
        () => SequenceGenerator(maxValue: 10, startValue: 11),
        throwsArgumentError,
      );
    });
  });
}