import 'package:flutter_test/flutter_test.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

void main() {
  group('FrameBuffer', () {
    late FrameBuffer buffer;
    late FrameBuilder builder;

    setUp(() {
      buffer = FrameBuffer();
      builder = FrameBuilder();
    });

    List<int> makeFrame({List<int> payload = const [0x01, 0x02]}) {
      return builder.build(
        version: 1,
        productId: 0,
        address: 0,
        op: 0xA5,
        commandId: 0x01,
        sequence: 1,
        flags: 0x00,
        payload: payload,
      );
    }

    // ---- Basic ----

    test('starts empty', () {
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, 0);
    });

    test('full frame in one chunk', () {
      final frameBytes = makeFrame();
      final frames = buffer.addBytes(frameBytes);

      expect(frames.length, 1);
      expect(frames[0].commandId, 0x01);
      expect(frames[0].payload, [0x01, 0x02]);
      expect(buffer.isEmpty, isTrue);
    });

    // ---- Chunking ----

    test('frame split into two chunks', () {
      final frameBytes = makeFrame();
      final mid = frameBytes.length ~/ 2;

      // First chunk: first half
      var frames = buffer.addBytes(frameBytes.sublist(0, mid));
      expect(frames.length, 0, reason: 'should not have complete frame yet');
      expect(buffer.isEmpty, isFalse);

      // Second chunk: second half
      frames = buffer.addBytes(frameBytes.sublist(mid));
      expect(frames.length, 1);
      expect(frames[0].commandId, 0x01);
      expect(buffer.isEmpty, isTrue);
    });

    test('frame split byte by byte', () {
      final frameBytes = makeFrame();

      for (var i = 0; i < frameBytes.length - 1; i++) {
        final frames = buffer.addBytes([frameBytes[i]]);
        expect(frames.length, 0, reason: 'at byte $i should not complete');
      }

      // Last byte completes the frame
      final frames = buffer.addBytes([frameBytes.last]);
      expect(frames.length, 1);
      expect(frames[0].commandId, 0x01);
    });

    test('frame split into many small chunks', () {
      final frameBytes = makeFrame();

      // Add in chunks of 3 bytes
      for (var i = 0; i < frameBytes.length; i += 3) {
        final end = (i + 3 > frameBytes.length) ? frameBytes.length : i + 3;
        final chunk = frameBytes.sublist(i, end);
        final frames = buffer.addBytes(chunk);
        // Only the last chunk should complete the frame
        if (end < frameBytes.length) {
          expect(frames.length, 0);
        }
      }

      expect(buffer.isEmpty, isTrue);
    });

    // ---- Garbage before SOF ----

    test('garbage bytes before SOF are discarded', () {
      final frameBytes = makeFrame();
      final garbage = [0x00, 0x00, 0xFF, 0xFE];

      final frames = buffer.addBytes([...garbage, ...frameBytes]);
      expect(frames.length, 1);
      expect(frames[0].commandId, 0x01);
      expect(buffer.isEmpty, isTrue);
    });

    test('garbage only (no SOF) clears buffer once enough bytes arrive', () {
      // Add enough bytes to exceed minFrameSize to trigger extraction
      final garbage = List<int>.generate(20, (i) => i);
      final frames = buffer.addBytes(garbage);
      expect(frames.length, 0);
      // Buffer should be cleared since no SOF was found
      expect(buffer.isEmpty, isTrue);
    });

    // ---- Multiple frames ----

    test('two frames in one chunk', () {
      final frame1 = makeFrame(payload: [0x01]);
      final frame2 = makeFrame(payload: [0x02]);

      final frames = buffer.addBytes([...frame1, ...frame2]);
      expect(frames.length, 2);
      expect(frames[0].commandId, 0x01);
      expect(frames[1].commandId, 0x01);
      expect(buffer.isEmpty, isTrue);
    });

    test('two frames delivered in separate chunks', () {
      final frame1 = makeFrame(payload: [0x01]);
      final frame2 = makeFrame(payload: [0x02]);

      // First frame in one chunk
      var frames = buffer.addBytes(frame1);
      expect(frames.length, 1);
      expect(buffer.isEmpty, isTrue);

      // Second frame in another chunk
      frames = buffer.addBytes(frame2);
      expect(frames.length, 1);
      expect(buffer.isEmpty, isTrue);
    });

    // ---- Incomplete frame remains buffered ----

    test('incomplete frame remains buffered for next addBytes', () {
      final frameBytes = makeFrame();
      final half = frameBytes.sublist(0, 10); // Only first 10 bytes

      var frames = buffer.addBytes(half);
      expect(frames.length, 0);
      expect(buffer.isEmpty, isFalse);
      expect(buffer.length, 10);

      // Add remaining bytes
      frames = buffer.addBytes(frameBytes.sublist(10));
      expect(frames.length, 1);
      expect(buffer.isEmpty, isTrue);
    });

    test('incomplete frame does not block subsequent complete frame', () {
      final frame1 = makeFrame(payload: [0x01]);
      final frame2 = makeFrame(payload: [0x02]);

      // Take some bytes from frame1 that DON'T start with SOF, so the buffer
      // will skip past them to find frame2. We use the last 5 bytes of frame1
      // (bytes that are definitely not SOF).
      final nonSofChunk = frame1.sublist(frame1.length - 5);
      final frames = buffer.addBytes([...nonSofChunk, ...frame2]);
      // frame2 should be complete
      expect(frames.length, 1);
      expect(frames[0].payload, [0x02]);
      // non-SOF bytes that came before SOF should be discarded
      expect(buffer.isEmpty, isTrue);
    });

    // ---- Invalid frame handling ----

    test('invalid frame (bad CRC) is discarded, next valid frame extracted', () {
      final goodFrame = makeFrame(payload: [0xAA]);
      final badFrame = makeFrame(payload: [0xBB]);

      // Corrupt the CRC of badFrame
      badFrame[badFrame.length - 3] = 0x00;
      badFrame[badFrame.length - 2] = 0x00;

      // Add bad frame followed by good frame
      final frames = buffer.addBytes([...badFrame, ...goodFrame]);
      // Only the good frame should be returned
      expect(frames.length, 1);
      expect(frames[0].payload, [0xAA]);
    });

    test('invalid frame (bad SOF) is discarded', () {
      final frameBytes = makeFrame();
      frameBytes[0] = 0xBB; // Invalid SOF

      final frames = buffer.addBytes(frameBytes);
      expect(frames.length, 0);
    });

    // ---- Clear ----

    test('clear empties the buffer', () {
      final frameBytes = makeFrame();
      buffer.addBytes(frameBytes.sublist(0, 5));
      expect(buffer.isEmpty, isFalse);

      buffer.clear();
      expect(buffer.isEmpty, isTrue);
    });

    // ---- Max buffer size ----

    test('buffer trims when exceeding max size', () {
      final smallBuffer = FrameBuffer(maxBufferSize: 20);
      final frameBytes = makeFrame(payload: List.filled(50, 0x01));

      // Add a large frame that exceeds max buffer size
      smallBuffer.addBytes(frameBytes);
      // The frame should be too large to fit, so it gets trimmed
      // and no frame should be extracted
      expect(smallBuffer.length, lessThanOrEqualTo(20));
    });
  });
}
