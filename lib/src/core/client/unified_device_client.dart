import 'dart:async';

import 'unified_device_client_config.dart';
import 'unified_device_session.dart';
import '../errors/transport_exception.dart';
import '../errors/unified_device_exception.dart';
import '../frame/device_frame.dart';
import '../frame/frame_buffer.dart';
import '../frame/frame_builder.dart';
import '../response/device_event.dart';
import '../response/device_response.dart';
import '../response/response_manager.dart';
import '../transport/ble_transport.dart';
import '../transport/connection_state.dart';
import '../transport/device_transport.dart';
import '../transport/discovered_device.dart';
import '../../protocol/commands/command_options.dart';
import '../../protocol/constants/protocol_constants.dart';

/// Generic client for discovery, connection, and frame-based command exchange.
class UnifiedDeviceClient {
  final UnifiedDeviceClientConfig _config;
  final DeviceTransport _transport;
  final FrameBuilder _frameBuilder;
  final FrameBuffer _frameBuffer;
  final ResponseManager _responseManager;

  StreamSubscription<DeviceConnectionState>? _connectionSubscription;

  UnifiedDeviceSession? _currentSession;
  bool _isDisposed = false;

  /// Creates a client from an explicit configuration.
  UnifiedDeviceClient(this._config)
      : _transport = _config.transport,
        _frameBuilder = FrameBuilder(
          sof: _config.sofDelimiter,
          eof: _config.eofDelimiter,
        ),
        _frameBuffer = FrameBuffer(
          sofDelimiter: _config.sofDelimiter,
        ),
        _responseManager = ResponseManager(
          transport: _config.transport,
          defaultTimeout: _config.defaultTimeout,
          frameBuilder: FrameBuilder(
            sof: _config.sofDelimiter,
            eof: _config.eofDelimiter,
          ),
          frameBuffer: FrameBuffer(
            sofDelimiter: _config.sofDelimiter,
          ),
          protocolVersion: _config.protocolVersion,
        ) {
    _bindConnectionState();
  }

  /// Creates a client with a generic BLE transport by default.
  factory UnifiedDeviceClient.generic({
    DeviceTransport? transport,
    Duration defaultTimeout = const Duration(seconds: 5),
    bool autoReconnect = false,
    int maxReconnectAttempts = 3,
    Duration reconnectDelay = const Duration(seconds: 2),
    int sofDelimiter = ProtocolConstants.sof,
    int eofDelimiter = ProtocolConstants.eof,
    int protocolVersion = ProtocolConstants.currentProtocolVersion,
  }) {
    return UnifiedDeviceClient(
      UnifiedDeviceClientConfig(
        transport: transport ?? BleTransport(),
        defaultTimeout: defaultTimeout,
        autoReconnect: autoReconnect,
        maxReconnectAttempts: maxReconnectAttempts,
        reconnectDelay: reconnectDelay,
        sofDelimiter: sofDelimiter,
        eofDelimiter: eofDelimiter,
        protocolVersion: protocolVersion,
      ),
    );
  }

  /// Underlying transport used by the client.
  DeviceTransport get transport => _transport;

  /// Underlying frame builder used by the client.
  FrameBuilder get frameBuilder => _frameBuilder;

  /// Underlying frame buffer configuration used by the client.
  FrameBuffer get frameBuffer => _frameBuffer;

  /// Current session, when connected.
  UnifiedDeviceSession? get currentSession => _currentSession;

  /// Whether the client is connected.
  bool get isConnected =>
      _currentSession != null &&
      _currentSession!.state == DeviceConnectionState.connected;

  /// Whether the transport is currently scanning.
  bool get isScanning => _transport.isScanning;

  /// Stream of discovered devices.
  Stream<DiscoveredDevice> get discoveredDevices => _transport.discoveredDevices;

  /// Stream of connection state updates.
  Stream<DeviceConnectionState> get connectionState => _transport.connectionState;

  /// Stream of generic EVENT frames.
  Stream<DeviceEvent> get events => _responseManager.events;

  /// Stream of parsed inbound frames.
  Stream<DeviceFrame> get frames => _responseManager.frames;

  /// Legacy alias retained for existing call sites.
  Stream<DiscoveredDevice> get onDeviceDiscovered => discoveredDevices;

  /// Legacy alias retained for existing call sites.
  Stream<DeviceConnectionState> get onConnectionStateChanged => connectionState;

  /// Legacy alias retained for existing call sites.
  Stream<DeviceEvent> get onDeviceEvent => events;

  void _bindConnectionState() {
    _connectionSubscription = _transport.connectionState.listen(
      (state) {
        switch (state) {
          case DeviceConnectionState.connected:
            if (_transport.connectedDeviceId != null) {
              _currentSession = UnifiedDeviceSession(
                deviceId: _transport.connectedDeviceId!,
                state: DeviceConnectionState.connected,
              );
            }
            break;
          case DeviceConnectionState.disconnected:
          case DeviceConnectionState.connectionLost:
            _currentSession = null;
            break;
          default:
            if (_currentSession != null) {
              _currentSession!.state = state;
            }
            break;
        }
      },
    );
  }

  Future<void> startScan() async {
    _throwIfDisposed();
    await _transport.startScan();
  }

  Future<void> stopScan() async {
    _throwIfDisposed();
    await _transport.stopScan();
  }

  Future<void> connect(DiscoveredDevice device) async {
    _throwIfDisposed();
    await _transport.connect(device);
  }

  Future<void> disconnect() async {
    _throwIfDisposed();
    await _transport.disconnect();
  }

  /// Sends a generic command and waits according to [options].
  Future<DeviceResponse> sendCommand({
    required int productId,
    required int op,
    required int commandId,
    List<int> payload = const [],
    int address = 0,
    int flags = 0,
    CommandOptions options = const CommandOptions(),
    Duration? timeout,
  }) async {
    _throwIfDisposed();
    _validateCommandInput(
      productId: productId,
      op: op,
      commandId: commandId,
      payload: payload,
      address: address,
      flags: flags,
    );
    _throwIfNotConnected();

    return _responseManager.sendCommand(
      commandId: commandId,
      productId: productId,
      address: address,
      op: op,
      version: _config.protocolVersion,
      payload: payload,
      flags: flags,
      options: timeout == null
          ? options
          : options.copyWith(
              ackTimeout: timeout,
              dataTimeout: timeout,
            ),
    );
  }

  /// Sends a prebuilt frame through the generic manager pipeline.
  Future<void> sendFrame(DeviceFrame frame) async {
    _throwIfDisposed();
    _throwIfNotConnected();
    await _responseManager.sendFrame(frame);
  }

  /// Sends raw bytes directly through the transport.
  Future<void> sendRawData(List<int> data) async {
    _throwIfDisposed();
    _throwIfNotConnected();
    await _transport.write(data);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    await _connectionSubscription?.cancel();
    _responseManager.dispose();
    await _transport.dispose();
    _currentSession = null;
  }

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw const UnifiedDeviceException('Client has been disposed');
    }
  }

  void _throwIfNotConnected() {
    if (!isConnected) {
      throw const TransportException('Not connected to any device');
    }
  }

  void _validateCommandInput({
    required int productId,
    required int op,
    required int commandId,
    required List<int> payload,
    required int address,
    required int flags,
  }) {
    _validateUint16(productId, 'productId');
    _validateUint32(address, 'address');
    _validateUint8(op, 'op');
    _validateUint8(commandId, 'commandId');
    _validateUint8(flags, 'flags');
    for (var i = 0; i < payload.length; i++) {
      _validateUint8(payload[i], 'payload[$i]');
    }
  }

  void _validateUint8(int value, String name) {
    if (value < 0 || value > 255) {
      throw ArgumentError('$name must be 0-255, but got $value');
    }
  }

  void _validateUint16(int value, String name) {
    if (value < 0 || value > 65535) {
      throw ArgumentError('$name must be 0-65535, but got $value');
    }
  }

  void _validateUint32(int value, String name) {
    if (value < 0 || value > 4294967295) {
      throw ArgumentError('$name must be 0-4294967295, but got $value');
    }
  }
}
