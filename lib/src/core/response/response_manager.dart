import 'dart:async';

import '../errors/protocol_exception.dart';
import '../errors/timeout_exception.dart';
import '../errors/transport_exception.dart';
import '../frame/device_frame.dart';
import '../frame/frame_buffer.dart';
import '../frame/frame_builder.dart';
import '../transport/connection_state.dart';
import '../transport/device_transport.dart';
import '../../protocol/commands/command_options.dart';
import '../../protocol/constants/operation_codes.dart';
import 'device_event.dart';
import 'device_response.dart';
import 'pending_request.dart';
import 'sequence_generator.dart';

/// Manages command lifecycle, response matching, and generic event emission.
class ResponseManager {
  final DeviceTransport _transport;
  final FrameBuilder _frameBuilder;
  final FrameBuffer _frameBuffer;
  final SequenceGenerator _sequenceGenerator;
  final int _protocolVersion;

  final Map<int, PendingRequest> _pendingRequests = {};
  final StreamController<DeviceEvent> _eventController =
      StreamController<DeviceEvent>.broadcast();
  final StreamController<DeviceFrame> _frameController =
      StreamController<DeviceFrame>.broadcast();

  StreamSubscription<List<int>>? _incomingSubscription;
  StreamSubscription<DeviceConnectionState>? _connectionSubscription;

  /// Default timeout for command operations.
  final Duration defaultTimeout;

  bool _isDisposed = false;

  ResponseManager({
    required DeviceTransport transport,
    this.defaultTimeout = const Duration(seconds: 5),
    FrameBuilder? frameBuilder,
    FrameBuffer? frameBuffer,
    SequenceGenerator? sequenceGenerator,
    int protocolVersion = 1,
  }) : _transport = transport,
       _frameBuilder = frameBuilder ?? FrameBuilder(),
       _frameBuffer = frameBuffer ?? FrameBuffer(),
       _sequenceGenerator = sequenceGenerator ?? SequenceGenerator(),
       _protocolVersion = protocolVersion {
    _bindTransport();
  }

  /// Stream of generic EVENT frames.
  Stream<DeviceEvent> get events => _eventController.stream;

  /// Stream of parsed inbound frames.
  Stream<DeviceFrame> get frames => _frameController.stream;

  /// The number of currently pending requests.
  int get pendingCount => _pendingRequests.length;

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
    int address = 0,
    int op = OperationCodes.read,
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
    final pending = PendingRequest(
      sequence: sequence,
      productId: productId,
      address: address,
      commandId: commandId,
      op: op,
      flags: flags,
      payload: payload,
      options: effectiveOptions,
    );

    _pendingRequests[sequence] = pending;

    final frameBytes = _frameBuilder.build(
      version: version == -1 ? _protocolVersion : version,
      productId: productId,
      address: address,
      op: op,
      commandId: commandId,
      sequence: sequence,
      flags: flags,
      payload: payload,
    );

    try {
      await _transport.write(frameBytes);
    } on Object {
      _pendingRequests.remove(sequence);
      rethrow;
    }

    if (!effectiveOptions.waitForAck && !effectiveOptions.waitForData) {
      _pendingRequests.remove(sequence);
      final response = DeviceResponse.success(
        sequence: sequence,
        productId: productId,
        address: address,
        commandId: commandId,
        op: op,
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
    await _transport.write(_frameBuilder.buildFromFrame(frame));
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

    if (frame.isEvent) {
      _emitEvent(DeviceEvent.fromFrame(frame, inferEventCodeFromPayload: true));
      return;
    }

    final pending = _pendingRequests[frame.sequence];
    if (pending == null) {
      return;
    }

    final response = DeviceResponse.fromFrame(
      frame,
      errorMessage: frame.isNack ? 'Device returned NACK' : null,
    );

    if (frame.isAck) {
      _handleAck(pending, response);
      return;
    }

    if (frame.isNack) {
      _handleNack(pending, response);
      return;
    }

    if (frame.isData) {
      _handleData(pending, response);
    }
  }

  void _handleAck(PendingRequest pending, DeviceResponse response) {
    pending.markAckReceived(response);

    if (!pending.options.waitForData) {
      _pendingRequests.remove(pending.sequence);
      pending.complete(response);
      return;
    }

    pending.startDataTimeout(_onDataTimeout);
  }

  void _handleNack(PendingRequest pending, DeviceResponse response) {
    _pendingRequests.remove(pending.sequence);
    pending.completeError(
      ProtocolException(
        response.errorMessage ?? 'Device returned NACK',
        errorCode: response.payload.isNotEmpty
            ? response.payload.first
            : response.flags,
        protocolErrorType: ProtocolErrorType.nackReceived,
      ),
    );
  }

  void _handleData(PendingRequest pending, DeviceResponse response) {
    if (pending.options.waitForAck && !pending.ackReceived) {
      return;
    }

    if (!pending.options.waitForData) {
      return;
    }

    _pendingRequests.remove(pending.sequence);
    pending.complete(response);
  }

  void _emitEvent(DeviceEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Fails a pending request by sequence number.
  void cancelRequest(int sequenceNumber) {
    final pending = _pendingRequests.remove(sequenceNumber);
    if (pending == null) {
      return;
    }
    pending.completeError(
      TimeoutException(
        'Request cancelled',
        timeoutDuration: Duration.zero,
        operation: 'Request $sequenceNumber',
      ),
    );
  }

  /// Fails all pending requests with a cancellation timeout exception.
  void cancelAll() {
    final requests = Map<int, PendingRequest>.from(_pendingRequests);
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
    final requests = Map<int, PendingRequest>.from(_pendingRequests);
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
    _pendingRequests.remove(request.sequence);
    request.completeError(
      TimeoutException(
        'Request ${request.sequence} timed out waiting for ACK',
        timeoutDuration: request.options.ackTimeout,
        operation: 'Request ${request.sequence} ACK',
      ),
    );
  }

  void _onDataTimeout(PendingRequest request) {
    _pendingRequests.remove(request.sequence);
    request.completeError(
      TimeoutException(
        'Request ${request.sequence} timed out waiting for DATA',
        timeoutDuration: request.options.dataTimeout,
        operation: 'Request ${request.sequence} DATA',
      ),
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
  }

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('ResponseManager has been disposed');
    }
  }
}
