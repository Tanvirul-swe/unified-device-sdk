import 'dart:async';

import '../errors/protocol_exception.dart';
import '../errors/timeout_exception.dart';
import '../errors/transport_exception.dart';
import '../frame/device_frame.dart';
import '../frame/frame_buffer.dart';
import '../frame/frame_builder.dart';
import '../frame/frame_parser.dart';
import '../transport/connection_state.dart';
import '../transport/device_transport.dart';
import '../../protocol/commands/command_options.dart';
import '../../protocol/constants/command_classes.dart';
import '../../protocol/constants/operation_codes.dart';
import '../../protocol/constants/profile_ids.dart';
import '../../protocol/constants/ucp_addresses.dart';
import '../../protocol/models/decoded_tlv.dart';
import '../../protocol/models/ucp_packet_trace.dart';
import '../../protocol/parsers/common_response_parser.dart';
import '../../protocol/parsers/nack_parser.dart';
import 'device_event.dart';
import 'device_response.dart';
import 'pending_request.dart';
import 'sequence_generator.dart';

/// Manages request/response correlation for official UCP traffic.
class UcpResponseManager {
  final DeviceTransport _transport;
  final FrameBuilder _frameBuilder;
  final FrameBuffer _frameBuffer;
  final FrameParser _frameParser;
  final SequenceGenerator _sequenceGenerator;
  final int _protocolVersion;
  final CommonResponseParser _responseParser;
  final NackParser _nackParser;

  final Map<_PendingRequestKey, PendingRequest> _pendingRequests =
      <_PendingRequestKey, PendingRequest>{};
  final StreamController<DeviceEvent> _eventController =
      StreamController<DeviceEvent>.broadcast();
  final StreamController<DeviceFrame> _frameController =
      StreamController<DeviceFrame>.broadcast();
  final StreamController<DeviceResponse> _dataController =
      StreamController<DeviceResponse>.broadcast();
  final StreamController<DeviceFrame> _streamController =
      StreamController<DeviceFrame>.broadcast();
  final StreamController<UcpPacketTrace> _traceController =
      StreamController<UcpPacketTrace>.broadcast();

  StreamSubscription<List<int>>? _incomingSubscription;
  StreamSubscription<DeviceConnectionState>? _connectionSubscription;
  bool _isDisposed = false;

  /// Default timeout for command operations.
  final Duration defaultTimeout;

  UcpResponseManager({
    required DeviceTransport transport,
    this.defaultTimeout = const Duration(seconds: 5),
    FrameBuilder? frameBuilder,
    FrameBuffer? frameBuffer,
    FrameParser? frameParser,
    SequenceGenerator? sequenceGenerator,
    int protocolVersion = 1,
    CommonResponseParser responseParser = const CommonResponseParser(),
  }) : _transport = transport,
       _frameBuilder = frameBuilder ?? FrameBuilder(),
       _frameBuffer = frameBuffer ?? FrameBuffer(),
       _frameParser = frameParser ?? FrameParser(),
       _sequenceGenerator = sequenceGenerator ?? SequenceGenerator(),
       _protocolVersion = protocolVersion,
       _responseParser = responseParser,
       _nackParser = NackParser(responseParser: responseParser) {
    _bindTransport();
  }

  /// Stream of generic EVENT frames.
  Stream<DeviceEvent> get events => _eventController.stream;

  /// Stream of parsed inbound frames.
  Stream<DeviceFrame> get frames => _frameController.stream;

  /// Stream of DATA frames, including unmatched unsolicited DATA packets.
  Stream<DeviceResponse> get dataResponses => _dataController.stream;

  /// Stream of STREAM frames.
  Stream<DeviceFrame> get streamFrames => _streamController.stream;

  /// Timestamped packet trace stream for diagnostics.
  Stream<UcpPacketTrace> get packetTraces => _traceController.stream;

  /// The number of currently pending requests.
  int get pendingCount => _pendingRequests.length;

  List<DecodedTlv> decodeTlvs(DeviceFrame frame) {
    return _responseParser.decodeFrame(frame);
  }

  void _bindTransport() {
    _incomingSubscription = _transport.incomingBytes.listen(
      processIncomingBytes,
    );

    _connectionSubscription = _transport.connectionState.listen((state) {
      if (state == DeviceConnectionState.disconnected ||
          state == DeviceConnectionState.connectionLost) {
        failAllPendingOnDisconnect(state);
        _frameBuffer.clear();
      }
    });
  }

  /// Sends a command frame and tracks its expected response lifecycle.
  Future<DeviceResponse> sendCommand({
    required int commandId,
    int productId = 0,
    int profileId = ProfileIds.defaultProfile,
    int sourceAddress = UcpAddresses.defaultSource,
    int address = UcpAddresses.defaultDestination,
    int? destinationAddress,
    int op = OperationCodes.req,
    int commandClass = CommandClasses.system,
    int version = -1,
    List<int> payload = const [],
    int flags = 0,
    Duration? timeout,
    CommandOptions? options,
  }) async {
    _throwIfDisposed();

    final sequence = _sequenceGenerator.next();
    final effectiveOptions = _resolveOptions(
      timeout: timeout,
      options: options,
    );
    final resolvedDestination = destinationAddress ?? address;
    final pending = PendingRequest(
      sequence: sequence,
      productId: productId,
      profileId: profileId,
      sourceAddress: sourceAddress,
      destinationAddress: resolvedDestination,
      commandId: commandId,
      op: op,
      commandClass: commandClass,
      flags: flags,
      payload: payload,
      options: effectiveOptions,
    );
    final key = _PendingRequestKey(
      sequence: sequence,
      commandClass: commandClass,
      commandId: commandId,
    );
    _pendingRequests[key] = pending;

    final frameBytes = _frameBuilder.build(
      version: version == -1 ? _protocolVersion : version,
      productId: productId,
      profileId: profileId,
      sourceAddress: sourceAddress,
      destinationAddress: resolvedDestination,
      op: op,
      commandClass: commandClass,
      commandId: commandId,
      sequence: sequence,
      flags: flags,
      payload: payload,
    );

    try {
      await _transport.write(frameBytes);
      _emitTrace(UcpPacketDirection.tx, frameBytes);
    } on Object {
      _pendingRequests.remove(key);
      rethrow;
    }

    if (!effectiveOptions.waitForAck &&
        !effectiveOptions.waitForData &&
        !effectiveOptions.completeOnEvent) {
      _pendingRequests.remove(key);
      final response = DeviceResponse.success(
        sequence: sequence,
        productId: productId,
        profileId: profileId,
        sourceAddress: sourceAddress,
        destinationAddress: resolvedDestination,
        commandId: commandId,
        op: op,
        commandClass: commandClass,
        flags: flags,
        payload: payload,
      );
      pending.complete(response);
      return response;
    }

    if (effectiveOptions.waitForAck) {
      pending.startAckTimeout(_onAckTimeout);
    } else if (effectiveOptions.waitForData) {
      pending.startDataTimeout(_onDataTimeout);
    }

    return pending.future;
  }

  /// Sends a prebuilt frame through the transport without request tracking.
  Future<void> sendFrame(DeviceFrame frame) async {
    _throwIfDisposed();
    final bytes = _frameBuilder.buildFromFrame(frame);
    await _transport.write(bytes);
    _emitTrace(UcpPacketDirection.tx, bytes, frame: frame);
  }

  CommandOptions _resolveOptions({Duration? timeout, CommandOptions? options}) {
    if (options != null) {
      if (timeout == null) {
        return options;
      }
      return options.copyWith(ackTimeout: timeout, dataTimeout: timeout);
    }

    final effectiveTimeout = timeout ?? defaultTimeout;
    return CommandOptions(
      ackTimeout: effectiveTimeout,
      dataTimeout: effectiveTimeout,
      waitForAck: true,
      waitForData: false,
    );
  }

  /// Converts incoming raw bytes into frames and processes them.
  void processIncomingBytes(List<int> bytes) {
    _throwIfDisposed();
    final frames = _frameBuffer.addBytes(bytes);
    for (final frame in frames) {
      processFrame(frame);
    }
  }

  /// Processes a parsed frame.
  void processFrame(DeviceFrame frame) {
    _throwIfDisposed();
    if (!_frameController.isClosed) {
      _frameController.add(frame);
    }
    _emitTrace(
      UcpPacketDirection.rx,
      _frameBuilder.buildFromFrame(frame),
      frame: frame,
    );

    if (frame.isEvent) {
      final event = DeviceEvent.fromFrame(
        frame,
        inferEventCodeFromPayload: true,
      );
      _emitEvent(event);
      final pending = _pendingRequests[_keyForFrame(frame)];
      if (pending != null && pending.options.completeOnEvent) {
        _pendingRequests.remove(_keyForFrame(frame));
        pending.complete(DeviceResponse.fromFrame(frame));
      }
      return;
    }

    if (frame.isStream) {
      if (!_streamController.isClosed) {
        _streamController.add(frame);
      }
      return;
    }

    final response = DeviceResponse.fromFrame(
      frame,
      errorMessage: frame.isNack ? 'Device returned NACK' : null,
    );

    if (frame.isData && !_dataController.isClosed) {
      _dataController.add(response);
    }

    final pending = _pendingRequests[_keyForFrame(frame)];
    if (pending == null) {
      return;
    }

    if (frame.isAck) {
      _handleAck(_keyForFrame(frame), pending, response);
      return;
    }

    if (frame.isNack) {
      _handleNack(_keyForFrame(frame), pending, response);
      return;
    }

    if (frame.isData) {
      _handleData(_keyForFrame(frame), pending, response);
    }
  }

  void _handleAck(
    _PendingRequestKey key,
    PendingRequest pending,
    DeviceResponse response,
  ) {
    pending.markAckReceived(response);

    if (!pending.options.waitForData) {
      _pendingRequests.remove(key);
      pending.complete(response);
      return;
    }

    pending.startDataTimeout(_onDataTimeout);
  }

  void _handleNack(
    _PendingRequestKey key,
    PendingRequest pending,
    DeviceResponse response,
  ) {
    _pendingRequests.remove(key);
    final details = _nackParser.parseDetails(response);
    pending.completeError(
      ProtocolException(
        details.text ?? response.errorMessage ?? 'Device returned NACK',
        errorCode: details.errorCode ?? response.flags,
        protocolErrorType: ProtocolErrorType.nackReceived,
      ),
    );
  }

  void _handleData(
    _PendingRequestKey key,
    PendingRequest pending,
    DeviceResponse response,
  ) {
    if (pending.options.waitForAck && !pending.ackReceived) {
      return;
    }

    if (!pending.options.waitForData) {
      return;
    }

    _pendingRequests.remove(key);
    pending.complete(response);
  }

  void _emitEvent(DeviceEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _emitTrace(
    UcpPacketDirection direction,
    List<int> bytes, {
    DeviceFrame? frame,
  }) {
    if (_traceController.isClosed) {
      return;
    }

    final resolvedFrame = frame ?? _tryParseFrame(bytes);
    final decodedTlvs = resolvedFrame == null
        ? const <DecodedTlv>[]
        : decodeTlvs(resolvedFrame);
    _traceController.add(
      UcpPacketTrace(
        direction: direction,
        bytes: bytes,
        frame: resolvedFrame,
        decodedTlvs: decodedTlvs,
      ),
    );
  }

  DeviceFrame? _tryParseFrame(List<int> bytes) {
    try {
      return _frameParser.parse(bytes);
    } on Object {
      return null;
    }
  }

  _PendingRequestKey _keyForFrame(DeviceFrame frame) {
    return _PendingRequestKey(
      sequence: frame.sequence,
      commandClass: frame.commandClass,
      commandId: frame.commandId,
    );
  }

  /// Fails a pending request by sequence number.
  void cancelRequest(int sequenceNumber) {
    MapEntry<_PendingRequestKey, PendingRequest>? matchedEntry;
    for (final entry in _pendingRequests.entries) {
      if (entry.value.sequence == sequenceNumber) {
        matchedEntry = entry;
        break;
      }
    }
    if (matchedEntry == null) {
      return;
    }
    _pendingRequests.remove(matchedEntry.key);
    matchedEntry.value.completeError(
      TimeoutException(
        'Request cancelled',
        timeoutDuration: Duration.zero,
        operation: 'Request $sequenceNumber',
      ),
    );
  }

  /// Fails all pending requests with a cancellation timeout exception.
  void cancelAll() {
    final requests = Map<_PendingRequestKey, PendingRequest>.from(
      _pendingRequests,
    );
    _pendingRequests.clear();
    for (final pending in requests.values) {
      pending.completeError(
        TimeoutException(
          'All requests cancelled',
          timeoutDuration: Duration.zero,
          operation: 'Request ${pending.sequence}',
        ),
      );
    }
  }

  /// Fails all pending requests because the transport disconnected.
  void failAllPendingOnDisconnect(DeviceConnectionState state) {
    final requests = Map<_PendingRequestKey, PendingRequest>.from(
      _pendingRequests,
    );
    _pendingRequests.clear();
    for (final pending in requests.values) {
      pending.completeError(
        TransportException(
          state == DeviceConnectionState.connectionLost
              ? 'Connection lost while waiting for response'
              : 'Disconnected while waiting for response',
          errorType: state == DeviceConnectionState.connectionLost
              ? TransportErrorType.connectionLost
              : TransportErrorType.connectionFailed,
        ),
      );
    }
  }

  void _onAckTimeout(PendingRequest request) {
    final key = _keyForPending(request);
    _pendingRequests.remove(key);
    request.completeError(
      TimeoutException(
        'Request ${request.sequence} timed out waiting for ACK',
        timeoutDuration: request.options.ackTimeout,
        operation: 'Request ${request.sequence} ACK',
      ),
    );
  }

  void _onDataTimeout(PendingRequest request) {
    final key = _keyForPending(request);
    _pendingRequests.remove(key);
    request.completeError(
      TimeoutException(
        'Request ${request.sequence} timed out waiting for DATA',
        timeoutDuration: request.options.dataTimeout,
        operation: 'Request ${request.sequence} DATA',
      ),
    );
  }

  _PendingRequestKey _keyForPending(PendingRequest request) {
    return _PendingRequestKey(
      sequence: request.sequence,
      commandClass: request.commandClass,
      commandId: request.commandId,
    );
  }

  /// Disposes the manager and cancels all pending requests.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    cancelAll();
    _incomingSubscription?.cancel();
    _connectionSubscription?.cancel();
    _eventController.close();
    _frameController.close();
    _dataController.close();
    _streamController.close();
    _traceController.close();
  }

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('UcpResponseManager has been disposed');
    }
  }
}

/// Backward-compatible alias class.
class ResponseManager extends UcpResponseManager {
  ResponseManager({
    required super.transport,
    super.defaultTimeout,
    super.frameBuilder,
    super.frameBuffer,
    super.frameParser,
    super.sequenceGenerator,
    super.protocolVersion,
    super.responseParser,
  });
}

class _PendingRequestKey {
  final int sequence;
  final int commandClass;
  final int commandId;

  const _PendingRequestKey({
    required this.sequence,
    required this.commandClass,
    required this.commandId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PendingRequestKey &&
          runtimeType == other.runtimeType &&
          sequence == other.sequence &&
          commandClass == other.commandClass &&
          commandId == other.commandId;

  @override
  int get hashCode => Object.hash(sequence, commandClass, commandId);
}
