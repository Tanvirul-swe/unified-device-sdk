import 'dart:async';

import 'unified_device_session.dart';
import '../errors/transport_exception.dart';
import '../response/device_event.dart';
import '../response/device_response.dart';
import '../response/response_manager.dart';
import '../transport/connection_state.dart';
import '../transport/device_transport.dart';
import '../../protocol/commands/command_options.dart';
import '../../protocol/constants/ble_constants.dart';
import '../../protocol/constants/command_classes.dart';
import '../../protocol/constants/command_ids.dart';
import '../../protocol/constants/operation_codes.dart';
import '../../protocol/constants/product_ids.dart';
import '../../protocol/constants/profile_ids.dart';
import '../../protocol/constants/protocol_constants.dart';
import '../../protocol/constants/tlv_types.dart';
import '../../protocol/constants/ucp_addresses.dart';
import '../../protocol/models/decoded_tlv.dart';
import '../../protocol/payloads/tlv_builder.dart';

/// Drives the official UCP bootstrap and session lifecycle on the Dart side.
class UcpSessionManager {
  final DeviceTransport _transport;
  final UcpResponseManager _responseManager;

  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();

  StreamSubscription<DeviceConnectionState>? _transportSubscription;
  StreamSubscription<DeviceEvent>? _eventSubscription;
  StreamSubscription<dynamic>? _streamSubscription;

  UnifiedDeviceSession? _currentSession;
  DeviceConnectionState _state = DeviceConnectionState.disconnected;
  Completer<void>? _bootstrapCompleter;
  Completer<void>? _disconnectCompleter;
  bool _bootstrapStarted = false;
  bool _isDisposed = false;

  // Heartbeat
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  int _missedHeartbeats = 0;
  static const int _maxMissedHeartbeats = 3;

  UcpSessionManager({
    required DeviceTransport transport,
    required UcpResponseManager responseManager,
  }) : _transport = transport,
       _responseManager = responseManager {
    _bind();
  }

  Stream<DeviceConnectionState> get states => _stateController.stream;
  DeviceConnectionState get state => _state;
  UnifiedDeviceSession? get currentSession => _currentSession;

  bool get isSessionActive => _currentSession?.sessionActive ?? false;

  void _bind() {
    _transportSubscription = _transport.connectionState.listen(
      _handleTransportState,
    );
    _eventSubscription = _responseManager.events.listen(_handleEvent);
    _streamSubscription = _responseManager.streamFrames.listen((_) {
      markStreamActive(true);
    });
  }

  Future<void> waitUntilSessionActive({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (isSessionActive) {
      return;
    }

    final completer = _bootstrapCompleter;
    if (completer == null) {
      throw const TransportException(
        'Session bootstrap has not started',
        errorType: TransportErrorType.connectionFailed,
      );
    }
    await completer.future.timeout(timeout);
  }

  Future<void> bootstrap() {
    if (isSessionActive) {
      return Future<void>.value();
    }
    return _startBootstrapIfNeeded();
  }

  Future<DeviceResponse> openTransport() {
    final payload = TlvBuilder()
        .addUtf8(TlvTypes.textUtf8, 'ELAB_UCP_CLIENT')
        .build();
    return _responseManager.sendCommand(
      productId: ProductIds.aunkurUcp1,
      profileId: ProfileIds.defaultProfile,
      sourceAddress: UcpAddresses.software,
      destinationAddress: UcpAddresses.device,
      op: OperationCodes.req,
      commandClass: CommandClasses.session,
      commandId: SessionCommandIds.btTransportOpen,
      payload: payload,
      options: const CommandOptions(
        waitForAck: true,
        waitForData: false,
        completeOnEvent: true,
      ),
    );
  }

  Future<DeviceResponse> openRtcSession({DateTime? now}) {
    final epochSeconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final payload = TlvBuilder()
        .addUint64BE(TlvTypes.epochU64, epochSeconds)
        .addUtf8(TlvTypes.textUtf8, 'ELAB_UCP_CLIENT')
        .build();
    return _responseManager.sendCommand(
      productId: ProductIds.aunkurUcp1,
      profileId: ProfileIds.defaultProfile,
      sourceAddress: UcpAddresses.software,
      destinationAddress: UcpAddresses.device,
      op: OperationCodes.req,
      commandClass: CommandClasses.session,
      commandId: SessionCommandIds.sessionOpenRtcSync,
      payload: payload,
      options: const CommandOptions(
        waitForAck: true,
        waitForData: false,
        completeOnEvent: true,
      ),
    );
  }

  Future<void> closeSession({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_currentSession == null) {
      await _transport.disconnect();
      return;
    }

    _currentSession!
      ..safeDisconnectPending = true
      ..measurementActive = false
      ..streamActive = false;
    _updateState(DeviceConnectionState.safeDisconnectPending);
    _disconnectCompleter ??= Completer<void>();

    try {
      await _responseManager.sendCommand(
        productId: ProductIds.aunkurUcp1,
        profileId: ProfileIds.defaultProfile,
        sourceAddress: UcpAddresses.software,
        destinationAddress: UcpAddresses.device,
        op: OperationCodes.req,
        commandClass: CommandClasses.session,
        commandId: SessionCommandIds.sessionClose,
        payload: TlvBuilder()
            .addUtf8(TlvTypes.textUtf8, 'normal close')
            .build(),
        options: const CommandOptions(
          waitForAck: true,
          waitForData: false,
          completeOnEvent: true,
        ),
      );
    } on Object {
      await _transport.disconnect();
      rethrow;
    }

    try {
      await _disconnectCompleter!.future.timeout(timeout);
    } on TimeoutException {
      await _transport.disconnect();
    }
  }

  void markMeasurementActive(bool active) {
    if (_currentSession == null) {
      return;
    }
    _currentSession!.measurementActive = active;
    if (!active) {
      _currentSession!.safeDisconnectPending = false;
    }
    _refreshOperationalState();
  }

  void markStreamActive(bool active) {
    if (_currentSession == null) {
      return;
    }
    _currentSession!.streamActive = active;
    _refreshOperationalState();
  }

  void _handleTransportState(DeviceConnectionState state) {
    switch (state) {
      case DeviceConnectionState.scanning:
      case DeviceConnectionState.connecting:
      case DeviceConnectionState.disconnecting:
      case DeviceConnectionState.servicesDiscovered:
      case DeviceConnectionState.notifySubscribed:
        _updateState(state);
        break;
      case DeviceConnectionState.connected:
        _currentSession = UnifiedDeviceSession(
          deviceId: _transport.connectedDeviceId ?? 'unknown',
          deviceName: BleConstants.defaultDeviceName,
          state: DeviceConnectionState.connected,
        );
        _bootstrapStarted = false;
        _updateState(DeviceConnectionState.connected);
        break;
      case DeviceConnectionState.mtuReady:
        _updateState(DeviceConnectionState.mtuReady);
        unawaited(_startBootstrapIfNeeded());
        break;
      case DeviceConnectionState.error:
        _updateState(DeviceConnectionState.error);
        break;
      case DeviceConnectionState.disconnected:
      case DeviceConnectionState.connectionLost:
        _stopHeartbeat();
        _currentSession = null;
        _bootstrapStarted = false;
        _updateState(state);
        _disconnectCompleter?.complete();
        _disconnectCompleter = null;
        if (_bootstrapCompleter != null && !_bootstrapCompleter!.isCompleted) {
          _bootstrapCompleter!.completeError(
            TransportException(
              state == DeviceConnectionState.connectionLost
                  ? 'Connection lost during session bootstrap'
                  : 'Disconnected during session bootstrap',
              errorType: state == DeviceConnectionState.connectionLost
                  ? TransportErrorType.connectionLost
                  : TransportErrorType.connectionFailed,
            ),
          );
        }
        _bootstrapCompleter = null;
        break;
      default:
        if (_shouldApplyTransportState(state)) {
          _updateState(state);
        }
        break;
    }
  }

  bool _shouldApplyTransportState(DeviceConnectionState nextState) {
    if (_state == nextState) {
      return true;
    }

    if (nextState == DeviceConnectionState.disconnected ||
        nextState == DeviceConnectionState.connectionLost ||
        nextState == DeviceConnectionState.error) {
      return true;
    }

    // Native BLE callbacks can report lower-level readiness states like
    // `mtuReady` after the UCP bootstrap has already advanced to
    // `transportReady` or `sessionActive`. Ignore those regressions.
    if (_state.index >= DeviceConnectionState.transportReady.index &&
        nextState.index < DeviceConnectionState.transportReady.index) {
      return false;
    }

    return true;
  }

  Future<void> _startBootstrapIfNeeded() {
    final completer = _bootstrapCompleter ??= Completer<void>();

    if (_bootstrapStarted ||
        _state == DeviceConnectionState.error ||
        _state == DeviceConnectionState.disconnected ||
        _state == DeviceConnectionState.connectionLost ||
        _state.index < DeviceConnectionState.mtuReady.index) {
      return completer.future;
    }

    _bootstrapStarted = true;
    unawaited(_runBootstrap(completer));
    return completer.future;
  }

  Future<void> _runBootstrap(Completer<void> completer) async {
    try {
      await openTransport();
      _updateState(DeviceConnectionState.transportReady);
      await openRtcSession();
      if (_currentSession != null) {
        _currentSession!
          ..sessionActive = true
          ..safeDisconnectPending = false;
      }
      _updateState(DeviceConnectionState.sessionActive);
      _startHeartbeat();
      completer.complete();
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      if (identical(_bootstrapCompleter, completer)) {
        _bootstrapCompleter = null;
        _bootstrapStarted = false;
      }
    }
  }

  void _handleEvent(DeviceEvent event) {
    final frame = event.sourceFrame;
    if (frame == null) {
      return;
    }

    // Reset heartbeat on any incoming frame from device
    _resetHeartbeatTimeout();

    if (frame.commandClass == CommandClasses.measurement &&
        frame.commandId == MeasurementCommandIds.startTest) {
      final decoded = _responseManager.decodeTlvs(frame);
      final status = _findInt(decoded, TlvTypes.statusU8);
      final text = _findString(decoded, TlvTypes.textUtf8);
      if (status == 4 ||
          (text != null && text.contains('report ready for last_report'))) {
        markMeasurementActive(false);
      } else {
        markMeasurementActive(true);
      }
    }

    if (frame.commandClass == CommandClasses.moisture &&
        frame.commandId == MoistureCommandIds.moistGetOff) {
      markStreamActive(false);
    }
  }

  int? _findInt(List<DecodedTlv> tlvs, int type) {
    for (final tlv in tlvs) {
      if (tlv.type == type && tlv.value is int) {
        return tlv.value as int;
      }
    }
    return null;
  }

  String? _findString(List<DecodedTlv> tlvs, int type) {
    for (final tlv in tlvs) {
      if (tlv.type == type && tlv.value is String) {
        return tlv.value as String;
      }
    }
    return null;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _missedHeartbeats = 0;
    _heartbeatTimer = Timer.periodic(
      ProtocolConstants.heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
    _missedHeartbeats = 0;
  }

  void _resetHeartbeatTimeout() {
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
    _missedHeartbeats = 0;
  }

  void _sendHeartbeat() {
    if (!isSessionActive || _isDisposed) {
      _stopHeartbeat();
      return;
    }
    unawaited(_sendHeartbeatFrame());
  }

  Future<void> _sendHeartbeatFrame() async {
    try {
      await _responseManager.sendCommand(
        productId: ProductIds.aunkurUcp1,
        profileId: ProfileIds.defaultProfile,
        sourceAddress: UcpAddresses.software,
        destinationAddress: UcpAddresses.device,
        op: OperationCodes.req,
        commandClass: CommandClasses.session,
        commandId: SessionCommandIds.heartbeat,
        options: const CommandOptions(
          waitForAck: true,
          waitForData: false,
          ackTimeout: ProtocolConstants.heartbeatTimeout,
        ),
      );
      _missedHeartbeats = 0;
    } on Object {
      _missedHeartbeats++;
      if (_missedHeartbeats >= _maxMissedHeartbeats) {
        _onHeartbeatMissed();
      }
    }
  }

  void _onHeartbeatMissed() {
    _stopHeartbeat();
    _updateState(DeviceConnectionState.connectionLost);
    unawaited(_transport.disconnect());
  }

  void _refreshOperationalState() {
    final session = _currentSession;
    if (session == null) {
      return;
    }
    if (session.safeDisconnectPending) {
      _updateState(DeviceConnectionState.safeDisconnectPending);
      return;
    }
    if (session.streamActive) {
      _updateState(DeviceConnectionState.streamActive);
      return;
    }
    if (session.measurementActive) {
      _updateState(DeviceConnectionState.measurementActive);
      return;
    }
    if (session.sessionActive) {
      _updateState(DeviceConnectionState.sessionActive);
    }
  }

  void _updateState(DeviceConnectionState state) {
    _state = state;
    if (_currentSession != null) {
      _currentSession!.state = state;
    }
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _transportSubscription?.cancel();
    await _eventSubscription?.cancel();
    await _streamSubscription?.cancel();
    await _stateController.close();
  }
}
