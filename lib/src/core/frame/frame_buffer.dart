import '../bytes/endian_utils.dart';
import '../errors/crc_exception.dart';
import '../errors/frame_exception.dart';
import '../../protocol/constants/protocol_constants.dart';
import 'device_frame.dart';
import 'frame_parser.dart';

/// Receive buffer that reconstructs full frames across BLE notifications.
class UcpFrameBuffer {
  final List<int> _buffer = <int>[];
  final int maxBufferSize;
  final int sofDelimiter;
  final UcpFrameParser _parser;
  void Function(List<int> bytes, Object error)? onFrameError;

  UcpFrameBuffer({
    this.maxBufferSize = 4096,
    this.sofDelimiter = ProtocolConstants.sof,
    UcpFrameParser? parser,
    this.onFrameError,
  }) : _parser = parser ?? UcpFrameParser();

  int get length => _buffer.length;
  bool get isEmpty => _buffer.isEmpty;

  List<UcpFrame> addBytes(List<int> bytes) {
    _buffer.addAll(bytes);
    if (_buffer.length > maxBufferSize) {
      _buffer.removeRange(0, _buffer.length - maxBufferSize);
    }
    return _extractFrames();
  }

  void clear() {
    _buffer.clear();
  }

  List<UcpFrame> _extractFrames() {
    final frames = <UcpFrame>[];

    while (_buffer.length >= ProtocolConstants.minFrameSize) {
      final sofIndex = _buffer.indexOf(sofDelimiter);
      if (sofIndex == -1) {
        _buffer.clear();
        break;
      }

      if (sofIndex > 0) {
        _buffer.removeRange(0, sofIndex);
      }

      if (_buffer.length < ProtocolConstants.headerSize) {
        break;
      }

      final payloadLength = EndianUtils.bytesToUint16BE(
        _buffer,
        ProtocolConstants.payloadLengthOffset,
      );
      if (payloadLength > ProtocolConstants.maxPayloadSize) {
        _buffer.removeAt(0);
        continue;
      }

      final totalLength =
          ProtocolConstants.headerSize +
          payloadLength +
          ProtocolConstants.trailerSize;
      if (_buffer.length < totalLength) {
        break;
      }

      final eofIndex = totalLength - 1;
      if (_buffer[eofIndex] != ProtocolConstants.eof) {
        _buffer.removeAt(0);
        continue;
      }

      final candidate = _buffer.sublist(0, totalLength);
      try {
        frames.add(_parser.parse(candidate));
        _buffer.removeRange(0, totalLength);
      } on FrameException catch (error) {
        onFrameError?.call(List<int>.unmodifiable(candidate), error);
        _buffer.removeAt(0);
      } on CrcException catch (error) {
        onFrameError?.call(List<int>.unmodifiable(candidate), error);
        _buffer.removeAt(0);
      }
    }

    return frames;
  }
}

/// Backward-compatible buffer that returns [DeviceFrame] objects.
class FrameBuffer extends UcpFrameBuffer {
  FrameBuffer({
    super.maxBufferSize,
    super.sofDelimiter,
    FrameParser? parser,
    super.onFrameError,
  }) : super(parser: parser);

  @override
  List<DeviceFrame> addBytes(List<int> bytes) {
    return super
        .addBytes(bytes)
        .map(DeviceFrame.fromUcpFrame)
        .toList(growable: false);
  }
}
