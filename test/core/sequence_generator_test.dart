import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('SequenceGenerator', () {
    test('starts at official sequence 0', () {
      final generator = SequenceGenerator();
      expect(generator.current, 0);
      expect(generator.next(), 0);
      expect(generator.next(), 1);
    });

    test('rolls over on the configured max value', () {
      final generator = SequenceGenerator(maxValue: 3, startValue: 2);
      expect(generator.next(), 2);
      expect(generator.next(), 3);
      expect(generator.next(), 0);
      expect(generator.next(), 1);
    });

    test('supports 16-bit custom start values', () {
      final generator = SequenceGenerator(startValue: 65535, maxValue: 65535);
      expect(generator.next(), 65535);
      expect(generator.next(), 0);
    });

    test('rejects startValue above maxValue', () {
      expect(
        () => SequenceGenerator(maxValue: 10, startValue: 11),
        throwsArgumentError,
      );
    });
  });
}
