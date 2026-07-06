import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

List<int> _hex(String value) {
  return value.split(' ').map((byte) => int.parse(byte, radix: 16)).toList();
}

void main() {
  group('UcpFrameBuffer', () {
    late UcpFrameBuffer buffer;

    setUp(() {
      buffer = UcpFrameBuffer();
    });

    test('reassembles a frame split across notifications', () {
      final bytes = _hex('DD 01 01 01 01 10 01 01 02 00 03 00 00 00 65 C6 77');

      expect(buffer.addBytes(bytes.sublist(0, 5)), isEmpty);
      final frames = buffer.addBytes(bytes.sublist(5));

      expect(frames, hasLength(1));
      expect(frames.single.commandId, SystemCommandIds.deviceInfo);
      expect(buffer.isEmpty, isTrue);
    });

    test('discards garbage before SOF and parses next frame', () {
      final bytes = _hex('DD 01 01 01 01 10 01 01 01 00 04 00 00 00 FA 0B 77');

      final frames = buffer.addBytes([0x00, 0xAA, 0x55, ...bytes]);
      expect(frames, hasLength(1));
      expect(frames.single.commandId, SystemCommandIds.time);
    });

    test('parses multiple frames from one chunk', () {
      final first = _hex('DD 01 01 01 01 10 01 01 02 00 03 00 00 00 65 C6 77');
      final second = _hex('DD 01 01 01 01 10 01 01 01 00 04 00 00 00 FA 0B 77');

      final frames = buffer.addBytes([...first, ...second]);
      expect(frames, hasLength(2));
      expect(frames.first.commandId, SystemCommandIds.deviceInfo);
      expect(frames.last.commandId, SystemCommandIds.time);
    });

    test('skips a bad frame and continues scanning', () {
      final bad = _hex('DD 01 01 01 01 10 01 01 02 00 03 00 00 00 65 00 77');
      final good = _hex('DD 01 01 01 01 10 01 01 01 00 04 00 00 00 FA 0B 77');

      final frames = buffer.addBytes([...bad, ...good]);
      expect(frames, hasLength(1));
      expect(frames.single.commandId, SystemCommandIds.time);
    });
  });
}
