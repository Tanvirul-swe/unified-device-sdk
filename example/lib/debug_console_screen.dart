import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

class DebugConsoleScreen extends StatefulWidget {
  final UnifiedDevicePlatform? platform;
  final bool enablePlatformBootstrap;

  const DebugConsoleScreen({
    super.key,
    this.platform,
    this.enablePlatformBootstrap = true,
  });

  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  static const int _maxLogItems = 200;
  static const int _headerBytes = 14;
  static const int _debugBufferLimit = 4096;

  late final UnifiedDevicePlatform _platform;
  late final UnifiedDeviceClient _client;
  late final FrameBuilder _frameBuilder;
  late final FrameParser _frameParser;
  late final SequenceGenerator _sequenceGenerator;
  late final List<StreamSubscription<dynamic>> _subscriptions;

  final Map<String, DiscoveredDevice> _devices = {};
  final List<_HexEntry> _sentFrames = <_HexEntry>[];
  final List<_HexEntry> _receivedChunks = <_HexEntry>[];
  final List<_ParsedFrameEntry> _parsedFrames = <_ParsedFrameEntry>[];
  final List<_CrcEntry> _crcEntries = <_CrcEntry>[];
  final List<_FrameBucketEntry> _ackEntries = <_FrameBucketEntry>[];
  final List<_FrameBucketEntry> _nackEntries = <_FrameBucketEntry>[];
  final List<_FrameBucketEntry> _eventEntries = <_FrameBucketEntry>[];
  final List<_FrameBucketEntry> _dataEntries = <_FrameBucketEntry>[];
  final List<_LogEntry> _commandLog = <_LogEntry>[];
  final List<_LogEntry> _errorLog = <_LogEntry>[];
  final List<int> _debugInputBuffer = <int>[];

  final TextEditingController _productIdController = TextEditingController(
    text: '0000',
  );
  final TextEditingController _opController = TextEditingController(text: 'A5');
  final TextEditingController _commandIdController = TextEditingController(
    text: '00',
  );
  final TextEditingController _addressController = TextEditingController(
    text: '00000000',
  );
  final TextEditingController _flagsController = TextEditingController(
    text: '00',
  );
  final TextEditingController _payloadController = TextEditingController();
  final TextEditingController _ackTimeoutController = TextEditingController(
    text: '5000',
  );
  final TextEditingController _dataTimeoutController = TextEditingController(
    text: '5000',
  );

  String? _platformVersion;
  bool? _bluetoothAvailable;
  bool? _bluetoothEnabled;
  bool? _permissionsGranted;
  bool _isRefreshingStatus = false;
  bool _isScanning = false;
  bool _isSending = false;
  bool _waitForAck = true;
  bool _waitForData = false;
  String? _selectedDeviceId;
  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;

  DiscoveredDevice? get _selectedDevice =>
      _selectedDeviceId == null ? null : _devices[_selectedDeviceId];

  bool get _isConnected => _connectionState == DeviceConnectionState.connected;

  @override
  void initState() {
    super.initState();
    _platform = widget.platform ?? UnifiedDevicePlatform.instance;
    _frameBuilder = FrameBuilder();
    _frameParser = FrameParser();
    _sequenceGenerator = SequenceGenerator();
    _client = UnifiedDeviceClient(
      UnifiedDeviceClientConfig(transport: BleTransport(platform: _platform)),
    );
    _subscriptions = <StreamSubscription<dynamic>>[
      _client.discoveredDevices.listen(
        _handleDeviceDiscovered,
        onError: (Object error, StackTrace stackTrace) {
          _recordError('scan', error, stackTrace);
        },
      ),
      _client.connectionState.listen(
        _handleConnectionStateChanged,
        onError: (Object error, StackTrace stackTrace) {
          _recordError('connection', error, stackTrace);
        },
      ),
      _client.transport.incomingBytes.listen(
        _handleIncomingBytes,
        onError: (Object error, StackTrace stackTrace) {
          _recordError('bytes', error, stackTrace);
        },
      ),
      _client.frames.listen(
        _handleParsedFrame,
        onError: (Object error, StackTrace stackTrace) {
          _recordError('frames', error, stackTrace);
        },
      ),
      _client.events.listen(
        _handleEvent,
        onError: (Object error, StackTrace stackTrace) {
          _recordError('events', error, stackTrace);
        },
      ),
    ];

    if (widget.enablePlatformBootstrap) {
      unawaited(_refreshBluetoothStatus());
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _productIdController.dispose();
    _opController.dispose();
    _commandIdController.dispose();
    _addressController.dispose();
    _flagsController.dispose();
    _payloadController.dispose();
    _ackTimeoutController.dispose();
    _dataTimeoutController.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _refreshBluetoothStatus() async {
    setState(() {
      _isRefreshingStatus = true;
    });

    try {
      final values = await Future.wait<Object?>([
        _platform.getPlatformVersion(),
        _platform.isBluetoothAvailable(),
        _platform.isBluetoothEnabled(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _platformVersion = values[0] as String?;
        _bluetoothAvailable = values[1] as bool;
        _bluetoothEnabled = values[2] as bool;
      });
    } on Object catch (error, stackTrace) {
      _recordError('status', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStatus = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final granted = await _platform.requestBluetoothPermissions();
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionsGranted = granted;
      });
      await _refreshBluetoothStatus();
    } on Object catch (error, stackTrace) {
      _recordError('permissions', error, stackTrace);
    }
  }

  Future<void> _toggleScan() async {
    try {
      if (_isScanning) {
        await _client.stopScan();
        if (!mounted) {
          return;
        }
        setState(() {
          _isScanning = false;
        });
        return;
      }

      setState(() {
        _devices.clear();
        _selectedDeviceId = null;
      });
      await _client.startScan();
      if (!mounted) {
        return;
      }
      setState(() {
        _isScanning = true;
      });
    } on Object catch (error, stackTrace) {
      _recordError('scan-control', error, stackTrace);
    }
  }

  Future<void> _connectSelectedDevice() async {
    final device = _selectedDevice;
    if (device == null) {
      _recordError(
        'connect',
        StateError('No device selected'),
        StackTrace.current,
      );
      return;
    }

    try {
      await _client.connect(device);
    } on Object catch (error, stackTrace) {
      _recordError('connect', error, stackTrace);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _client.disconnect();
    } on Object catch (error, stackTrace) {
      _recordError('disconnect', error, stackTrace);
    }
  }

  Future<void> _sendCommand() async {
    if (_isSending) {
      return;
    }

    try {
      final productId = _parseHexField(_productIdController.text, 'productId');
      final op = _parseHexField(_opController.text, 'op');
      final commandId = _parseHexField(_commandIdController.text, 'commandId');
      final address = _parseHexField(_addressController.text, 'address');
      final flags = _parseHexField(_flagsController.text, 'flags');
      final payload = _parseHexBytes(_payloadController.text);
      final ackTimeout = Duration(
        milliseconds: _parseDurationMs(
          _ackTimeoutController.text,
          'ackTimeout',
        ),
      );
      final dataTimeout = Duration(
        milliseconds: _parseDurationMs(
          _dataTimeoutController.text,
          'dataTimeout',
        ),
      );

      setState(() {
        _isSending = true;
      });

      final sequence = _sequenceGenerator.next();
      final frameBytes = _frameBuilder.build(
        version: ProtocolConstants.currentProtocolVersion,
        productId: productId,
        address: address,
        op: op,
        commandId: commandId,
        sequence: sequence,
        flags: flags,
        payload: payload,
      );

      _pushLimited(
        _sentFrames,
        _HexEntry(
          label: 'SEQ ${_formatHex(sequence, width: 2)}',
          hex: _toHex(frameBytes),
        ),
      );
      _pushLimited(
        _commandLog,
        _LogEntry(
          scope: 'send',
          message:
              'Queued command seq=${_formatHex(sequence, width: 2)} op=${_formatHex(op, width: 2)} cmd=${_formatHex(commandId, width: 2)} payload=${payload.length} bytes',
        ),
      );

      final response = await _client.sendCommand(
        productId: productId,
        op: op,
        commandId: commandId,
        payload: payload,
        address: address,
        flags: flags,
        options: CommandOptions(
          ackTimeout: ackTimeout,
          dataTimeout: dataTimeout,
          waitForAck: _waitForAck,
          waitForData: _waitForData,
        ),
      );

      _pushLimited(
        _commandLog,
        _LogEntry(
          scope: 'response',
          message:
              'Response seq=${_formatHex(response.sequence, width: 2)} op=${_formatHex(response.op, width: 2)} payload=${response.payload.length} bytes',
        ),
      );
    } on Object catch (error, stackTrace) {
      _recordError('send', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _handleDeviceDiscovered(DiscoveredDevice device) {
    setState(() {
      final current = _devices[device.deviceId];
      _devices[device.deviceId] = current == null
          ? device
          : current.copyWith(
              name: device.name,
              rssi: device.rssi,
              manufacturerData: device.manufacturerData,
              serviceUuids: device.serviceUuids,
              lastSeenAt: device.lastSeenAt,
              advertisementCount: device.advertisementCount,
            );
      _selectedDeviceId ??= device.deviceId;
    });
  }

  void _handleConnectionStateChanged(DeviceConnectionState state) {
    setState(() {
      _connectionState = state;
      if (state == DeviceConnectionState.disconnected ||
          state == DeviceConnectionState.connectionLost) {
        _isScanning = false;
      }
    });
    _pushLimited(
      _commandLog,
      _LogEntry(
        scope: 'connection',
        message: 'Connection state changed to ${state.name}',
      ),
    );
  }

  void _handleIncomingBytes(List<int> bytes) {
    _pushLimited(
      _receivedChunks,
      _HexEntry(label: '${bytes.length} bytes', hex: _toHex(bytes)),
    );

    _debugInputBuffer.addAll(bytes);
    if (_debugInputBuffer.length > _debugBufferLimit) {
      final excess = _debugInputBuffer.length - _debugBufferLimit;
      _debugInputBuffer.removeRange(0, excess);
    }

    while (_debugInputBuffer.length >= ProtocolConstants.minFrameSize) {
      final sofIndex = _debugInputBuffer.indexOf(ProtocolConstants.sof);
      if (sofIndex == -1) {
        _debugInputBuffer.clear();
        break;
      }
      if (sofIndex > 0) {
        _debugInputBuffer.removeRange(0, sofIndex);
      }
      if (_debugInputBuffer.length < _headerBytes) {
        break;
      }

      final declaredPayloadLength = EndianUtils.bytesToUint16BE(
        _debugInputBuffer,
        12,
      );
      final totalFrameSize =
          _headerBytes + declaredPayloadLength + ProtocolConstants.trailerSize;
      if (_debugInputBuffer.length < totalFrameSize) {
        break;
      }

      final candidate = _debugInputBuffer.sublist(0, totalFrameSize);
      _debugInputBuffer.removeRange(0, totalFrameSize);
      final hex = _toHex(candidate);

      try {
        _frameParser.parse(candidate);
        _pushLimited(
          _crcEntries,
          _CrcEntry(hex: hex, result: 'CRC valid', isValid: true),
        );
      } on CrcException catch (error) {
        _pushLimited(
          _crcEntries,
          _CrcEntry(
            hex: hex,
            result:
                'CRC invalid expected=${_formatHex(error.expectedCrc, width: 4)} actual=${_formatHex(error.actualCrc, width: 4)}',
            isValid: false,
          ),
        );
      } on Object catch (error) {
        _pushLimited(
          _crcEntries,
          _CrcEntry(hex: hex, result: 'Frame invalid: $error', isValid: false),
        );
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleParsedFrame(DeviceFrame frame) {
    _pushLimited(
      _parsedFrames,
      _ParsedFrameEntry(frame: frame, hex: frame.toHexString()),
    );

    final bucketEntry = _FrameBucketEntry(
      opLabel: _operationLabel(frame.op),
      summary:
          'seq=${_formatHex(frame.sequence, width: 2)} cmd=${_formatHex(frame.commandId, width: 2)} payload=${frame.payload.length} bytes',
      frame: frame,
    );
    if (frame.isAck) {
      _pushLimited(_ackEntries, bucketEntry);
    } else if (frame.isNack) {
      _pushLimited(_nackEntries, bucketEntry);
    } else if (frame.isEvent) {
      _pushLimited(_eventEntries, bucketEntry);
    } else if (frame.isData) {
      _pushLimited(_dataEntries, bucketEntry);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleEvent(DeviceEvent event) {
    _pushLimited(
      _commandLog,
      _LogEntry(
        scope: 'event',
        message:
            'EVENT seq=${_formatHex(event.sequence, width: 2)} cmd=${_formatHex(event.commandId, width: 2)} payload=${event.payload.length} bytes',
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _recordError(String scope, Object error, StackTrace stackTrace) {
    final message = _formatErrorMessage(error);
    _pushLimited(_errorLog, _LogEntry(scope: scope, message: message));
    _pushLimited(
      _commandLog,
      _LogEntry(scope: 'error:$scope', message: message),
    );
    debugPrint('[UnifiedDeviceExample][$scope] $message');
    debugPrintStack(stackTrace: stackTrace);
    if (mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      setState(() {});
    }
  }

  String _formatErrorMessage(Object error) {
    if (error is PlatformException) {
      final buffer = StringBuffer('Platform error');
      if (error.code.isNotEmpty) {
        buffer.write(' [${error.code}]');
      }
      if (error.message != null && error.message!.isNotEmpty) {
        buffer.write(': ${error.message}');
      }
      final details = _formatErrorDetails(error.details);
      if (details != null) {
        buffer.write(' | $details');
      }
      return buffer.toString();
    }
    return error.toString();
  }

  String? _formatErrorDetails(Object? details) {
    if (details == null) {
      return null;
    }
    if (details is Map) {
      final entries = details.entries
          .where((entry) => entry.value != null)
          .map((entry) => '${entry.key}=${entry.value}')
          .toList();
      if (entries.isEmpty) {
        return null;
      }
      return entries.join(', ');
    }
    return details.toString();
  }

  void _clearLogs() {
    setState(() {
      _sentFrames.clear();
      _receivedChunks.clear();
      _parsedFrames.clear();
      _crcEntries.clear();
      _ackEntries.clear();
      _nackEntries.clear();
      _eventEntries.clear();
      _dataEntries.clear();
      _commandLog.clear();
      _errorLog.clear();
      _debugInputBuffer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevice = _selectedDevice;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Unified Device Debug Console'),
          actions: [
            IconButton(
              tooltip: 'Disconnect',
              onPressed: _isConnected ? _disconnect : null,
              icon: const Icon(Icons.link_off),
            ),
            IconButton(
              tooltip: 'Clear Logs',
              onPressed: _clearLogs,
              icon: const Icon(Icons.clear_all),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Status'),
              Tab(text: 'Scan'),
              Tab(text: 'Device'),
              Tab(text: 'Command'),
              Tab(text: 'Frames'),
              Tab(text: 'Errors'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStatusTab(context),
            _buildScanTab(context),
            _buildDeviceTab(context, selectedDevice),
            _buildCommandTab(context),
            _buildFramesTab(context),
            _buildErrorsTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryGrid(context, [
          _SummaryTile(
            label: 'Platform',
            value: _platformVersion ?? 'Unknown',
            accent: const Color(0xFF006C67),
          ),
          _SummaryTile(
            label: 'Bluetooth Available',
            value: _describeBool(_bluetoothAvailable),
            accent: const Color(0xFF004B87),
          ),
          _SummaryTile(
            label: 'Bluetooth Enabled',
            value: _describeBool(_bluetoothEnabled),
            accent: const Color(0xFF9A4D00),
          ),
          _SummaryTile(
            label: 'Permissions',
            value: _describeBool(_permissionsGranted),
            accent: const Color(0xFF5E3B76),
          ),
          _SummaryTile(
            label: 'Connection',
            value: _connectionState.name,
            accent: const Color(0xFF8A2E2E),
          ),
          _SummaryTile(
            label: 'Selected Device',
            value: _selectedDevice?.name ?? _selectedDevice?.deviceId ?? 'None',
            accent: const Color(0xFF306850),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _isRefreshingStatus ? null : _refreshBluetoothStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
            ),
            OutlinedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.verified_user),
              label: const Text('Request Permissions'),
            ),
            OutlinedButton.icon(
              onPressed: _isConnected ? _disconnect : null,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLogSection(
          context,
          title: 'Activity',
          entries: _commandLog,
          emptyText: 'No status activity yet.',
        ),
      ],
    );
  }

  Widget _buildScanTab(BuildContext context) {
    final devices = _devices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleScan,
                  icon: Icon(
                    _isScanning ? Icons.stop_circle : Icons.bluetooth_searching,
                  ),
                  label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _devices.clear();
                      _selectedDeviceId = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Devices'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: devices.isEmpty
              ? const Center(child: Text('No devices discovered yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final isSelected = device.deviceId == _selectedDeviceId;
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: _signalColor(device.rssi),
                          child: Text(
                            '${device.rssi}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        title: Text(device.name ?? 'Unnamed Device'),
                        subtitle: Text(
                          '${device.deviceId}\n'
                          'RSSI ${device.rssi} dBm • adverts ${device.advertisementCount}\n'
                          'Services ${device.serviceUuids.isEmpty ? 'none' : device.serviceUuids.join(', ')}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          setState(() {
                            _selectedDeviceId = device.deviceId;
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDeviceTab(BuildContext context, DiscoveredDevice? device) {
    if (device == null) {
      return const Center(child: Text('Select a device from the Scan tab.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name ?? 'Unnamed Device',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                _buildKeyValue('Device ID', device.deviceId),
                _buildKeyValue('RSSI', '${device.rssi} dBm'),
                _buildKeyValue(
                  'Manufacturer Data',
                  device.manufacturerData == null ||
                          device.manufacturerData!.isEmpty
                      ? 'None'
                      : _toHex(device.manufacturerData!),
                ),
                _buildKeyValue(
                  'Service UUIDs',
                  device.serviceUuids.isEmpty
                      ? 'None'
                      : device.serviceUuids.join(', '),
                ),
                _buildKeyValue('Connection State', _connectionState.name),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isConnected ? null : _connectSelectedDevice,
                icon: const Icon(Icons.link),
                label: const Text('Connect'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isConnected ? _disconnect : null,
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommandTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildHexField(
                        controller: _productIdController,
                        label: 'Product ID',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHexField(
                        controller: _opController,
                        label: 'OP',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHexField(
                        controller: _commandIdController,
                        label: 'Command ID',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildHexField(
                        controller: _addressController,
                        label: 'Address',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHexField(
                        controller: _flagsController,
                        label: 'Flags',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _payloadController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Payload Hex',
                    hintText: '01 02 0A FF',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ackTimeoutController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'ACK Timeout ms',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _dataTimeoutController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'DATA Timeout ms',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wait For ACK'),
                  value: _waitForAck,
                  onChanged: (value) {
                    setState(() {
                      _waitForAck = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wait For DATA'),
                  value: _waitForData,
                  onChanged: (value) {
                    setState(() {
                      _waitForData = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isConnected && !_isSending
                        ? _sendCommand
                        : null,
                    icon: const Icon(Icons.send),
                    label: Text(_isSending ? 'Sending...' : 'Send Command'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildHexSection(
          context,
          title: 'Sent Frame Hex Viewer',
          entries: _sentFrames,
          emptyText: 'No outgoing frames yet.',
        ),
        const SizedBox(height: 16),
        _buildLogSection(
          context,
          title: 'Command Log',
          entries: _commandLog,
          emptyText: 'No command activity yet.',
        ),
      ],
    );
  }

  Widget _buildFramesTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHexSection(
          context,
          title: 'Received Raw Bytes Viewer',
          entries: _receivedChunks,
          emptyText: 'No incoming raw bytes yet.',
        ),
        const SizedBox(height: 16),
        _buildCrcSection(context),
        const SizedBox(height: 16),
        _buildParsedFramesSection(context),
        const SizedBox(height: 16),
        _buildBucketSection(
          context,
          title: 'ACK Viewer',
          entries: _ackEntries,
          emptyText: 'No ACK frames.',
        ),
        const SizedBox(height: 16),
        _buildBucketSection(
          context,
          title: 'NACK Viewer',
          entries: _nackEntries,
          emptyText: 'No NACK frames.',
        ),
        const SizedBox(height: 16),
        _buildBucketSection(
          context,
          title: 'EVENT Viewer',
          entries: _eventEntries,
          emptyText: 'No EVENT frames.',
        ),
        const SizedBox(height: 16),
        _buildBucketSection(
          context,
          title: 'DATA Viewer',
          entries: _dataEntries,
          emptyText: 'No DATA frames.',
        ),
      ],
    );
  }

  Widget _buildErrorsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLogSection(
          context,
          title: 'Error Log Viewer',
          entries: _errorLog,
          emptyText: 'No errors logged.',
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(BuildContext context, List<_SummaryTile> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: 220,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 6,
                        decoration: BoxDecoration(
                          color: item.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildHexSection(
    BuildContext context, {
    required String title,
    required List<_HexEntry> entries,
    required String emptyText,
  }) {
    return _buildSectionCard(
      context,
      title: title,
      child: entries.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text(emptyText))
          : Column(
              children: entries
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      title: Text(
                        entry.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      subtitle: Text(
                        '${_formatTime(entry.timestamp)}\n${entry.hex}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildCrcSection(BuildContext context) {
    return _buildSectionCard(
      context,
      title: 'CRC Validation Result',
      child: _crcEntries.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No frames validated yet.'),
            )
          : Column(
              children: _crcEntries
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      leading: Icon(
                        entry.isValid ? Icons.verified : Icons.error_outline,
                        color: entry.isValid ? Colors.green : Colors.red,
                      ),
                      title: Text(entry.result),
                      subtitle: Text(
                        '${_formatTime(entry.timestamp)}\n${entry.hex}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildParsedFramesSection(BuildContext context) {
    return _buildSectionCard(
      context,
      title: 'Parsed Frame Viewer',
      child: _parsedFrames.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No parsed frames yet.'),
            )
          : Column(
              children: _parsedFrames
                  .map(
                    (entry) => ExpansionTile(
                      title: Text(
                        '${entry.frame.isAck
                            ? 'ACK'
                            : entry.frame.isNack
                            ? 'NACK'
                            : entry.frame.isEvent
                            ? 'EVENT'
                            : entry.frame.isData
                            ? 'DATA'
                            : 'FRAME'} '
                        'seq=${_formatHex(entry.frame.sequence, width: 2)} '
                        'cmd=${_formatHex(entry.frame.commandId, width: 2)}',
                      ),
                      subtitle: Text(_formatTime(entry.timestamp)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        _buildKeyValue(
                          'Product',
                          _formatHex(entry.frame.productId, width: 4),
                        ),
                        _buildKeyValue(
                          'Address',
                          _formatHex(entry.frame.address, width: 8),
                        ),
                        _buildKeyValue(
                          'OP',
                          _formatHex(entry.frame.op, width: 2),
                        ),
                        _buildKeyValue(
                          'Flags',
                          _formatHex(entry.frame.flags, width: 2),
                        ),
                        _buildKeyValue(
                          'Payload Length',
                          '${entry.frame.payload.length}',
                        ),
                        _buildKeyValue(
                          'CRC',
                          _formatHex(entry.frame.crc, width: 4),
                        ),
                        _buildKeyValue('Hex', entry.hex),
                      ],
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildBucketSection(
    BuildContext context, {
    required String title,
    required List<_FrameBucketEntry> entries,
    required String emptyText,
  }) {
    return _buildSectionCard(
      context,
      title: title,
      child: entries.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text(emptyText))
          : Column(
              children: entries
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      title: Text(entry.summary),
                      subtitle: Text(
                        '${_formatTime(entry.timestamp)}\n${entry.frame.toHexString()}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildLogSection(
    BuildContext context, {
    required String title,
    required List<_LogEntry> entries,
    required String emptyText,
  }) {
    return _buildSectionCard(
      context,
      title: title,
      child: entries.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text(emptyText))
          : Column(
              children: entries
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _scopeColor(entry.scope),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(entry.message),
                      subtitle: Text(
                        '${entry.scope.toUpperCase()} • ${_formatTime(entry.timestamp)}',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHexField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
      ),
      style: const TextStyle(fontFamily: 'monospace'),
    );
  }

  Widget _buildKeyValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  static void _pushLimited<T>(List<T> list, T value) {
    list.insert(0, value);
    if (list.length > _maxLogItems) {
      list.removeLast();
    }
  }

  static int _parseHexField(String raw, String name) {
    final normalized = raw.trim().replaceAll('0x', '').replaceAll('0X', '');
    if (normalized.isEmpty) {
      return 0;
    }
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) {
      throw FormatException('Invalid $name hex value: $raw');
    }
    return value;
  }

  static int _parseDurationMs(String raw, String name) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 0) {
      throw FormatException(
        '$name must be a non-negative integer in milliseconds',
      );
    }
    return value;
  }

  static List<int> _parseHexBytes(String raw) {
    if (raw.trim().isEmpty) {
      return const <int>[];
    }

    final tokens = raw
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((token) => token.isNotEmpty);
    return tokens.map((token) {
      final normalized = token.replaceAll('0x', '').replaceAll('0X', '');
      final value = int.tryParse(normalized, radix: 16);
      debugPrint('Parsing token: $token -> $value');
      if (value == null || value < 0 || value > 255) {
        throw FormatException('Invalid payload byte: $token');
      }
      return value;
    }).toList();
  }

  static String _toHex(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(' ');
  }

  static String _formatHex(int value, {required int width}) {
    return '0x${value.toRadixString(16).toUpperCase().padLeft(width, '0')}';
  }

  static String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  static String _describeBool(bool? value) {
    if (value == null) {
      return 'Unknown';
    }
    return value ? 'Yes' : 'No';
  }

  static Color _scopeColor(String scope) {
    switch (scope) {
      case 'event':
        return const Color(0xFF1D5C63);
      case 'response':
        return const Color(0xFF2A6F3F);
      case 'send':
        return const Color(0xFF8F5A00);
      case 'connection':
        return const Color(0xFF5E3B76);
      default:
        return const Color(0xFF8A2E2E);
    }
  }

  static Color _signalColor(int rssi) {
    if (rssi >= -60) {
      return const Color(0xFF2A6F3F);
    }
    if (rssi >= -75) {
      return const Color(0xFFB07400);
    }
    return const Color(0xFF7F4A4A);
  }

  static String _operationLabel(int op) {
    if (op == OperationCodes.ack) {
      return 'ACK';
    }
    if (op == OperationCodes.nack) {
      return 'NACK';
    }
    if (op == OperationCodes.event) {
      return 'EVENT';
    }
    if (op == OperationCodes.data) {
      return 'DATA';
    }
    return 'OP';
  }
}

class _SummaryTile {
  final String label;
  final String value;
  final Color accent;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.accent,
  });
}

class _HexEntry {
  final DateTime timestamp;
  final String label;
  final String hex;

  _HexEntry({required this.label, required this.hex, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class _ParsedFrameEntry {
  final DateTime timestamp;
  final DeviceFrame frame;
  final String hex;

  _ParsedFrameEntry({
    required this.frame,
    required this.hex,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _CrcEntry {
  final DateTime timestamp;
  final bool isValid;
  final String result;
  final String hex;

  _CrcEntry({
    required this.isValid,
    required this.result,
    required this.hex,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _FrameBucketEntry {
  final DateTime timestamp;
  final String opLabel;
  final String summary;
  final DeviceFrame frame;

  _FrameBucketEntry({
    required this.opLabel,
    required this.summary,
    required this.frame,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _LogEntry {
  final DateTime timestamp;
  final String scope;
  final String message;

  _LogEntry({required this.scope, required this.message, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}
