import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

import '../widgets/connection_status_bar.dart';
import 'soil_test_screen.dart';

class SoilTestConnectionScreen extends StatefulWidget {
  final UnifiedDevicePlatform? platform;

  const SoilTestConnectionScreen({super.key, this.platform});

  @override
  State<SoilTestConnectionScreen> createState() =>
      _SoilTestConnectionScreenState();
}

class _SoilTestConnectionScreenState extends State<SoilTestConnectionScreen> {
  static const int _maxActivityLines = 20;
  static const List<_ConnectionStep> _steps = <_ConnectionStep>[
    _ConnectionStep(
      state: DeviceConnectionState.scanning,
      title: '1. Scan device',
      subtitle: 'Discover nearby supported hardware.',
    ),
    _ConnectionStep(
      state: DeviceConnectionState.connected,
      title: '2. Connect',
      subtitle: 'Open the BLE link with the selected device.',
    ),
    _ConnectionStep(
      state: DeviceConnectionState.servicesDiscovered,
      title: '3. Discover services',
      subtitle: 'Confirm the required GATT services are present.',
    ),
    _ConnectionStep(
      state: DeviceConnectionState.notifySubscribed,
      title: '4. Subscribe notify',
      subtitle: 'Enable notification delivery from the device.',
    ),
    _ConnectionStep(
      state: DeviceConnectionState.mtuReady,
      title: '5. MTU ready',
      subtitle: 'Complete MTU negotiation or use the default.',
    ),
    _ConnectionStep(
      state: DeviceConnectionState.transportReady,
      title: '6. UCP transport ready',
      subtitle: 'BLE transport is ready for UCP frames.',
    ),
    _ConnectionStep(
      state: DeviceConnectionState.sessionActive,
      title: '7. UCP session active',
      subtitle: 'Handshake completed. Opening the soil test screen.',
    ),
  ];

  late final UnifiedDevicePlatform _platform;
  late final UnifiedDeviceClient _client;
  late final List<StreamSubscription<dynamic>> _subscriptions;

  final Map<String, DiscoveredDevice> _devices = <String, DiscoveredDevice>{};
  final Set<DeviceConnectionState> _reachedStates = <DeviceConnectionState>{};
  final List<String> _activityLines = <String>[];

  String? _selectedDeviceId;
  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;
  String? _platformVersion;
  bool? _bluetoothAvailable;
  bool? _bluetoothEnabled;
  bool? _permissionsGranted;
  int _pendingActions = 0;
  bool _navigatingToSoilTest = false;
  bool _transferredClientOwnership = false;

  DiscoveredDevice? get _selectedDevice =>
      _selectedDeviceId == null ? null : _devices[_selectedDeviceId];

  bool get _busy => _pendingActions > 0;

  bool get _canConnect =>
      _selectedDevice != null &&
      (_connectionState == DeviceConnectionState.disconnected ||
          _connectionState == DeviceConnectionState.connectionLost);

  bool get _canDisconnect =>
      _connectionState != DeviceConnectionState.disconnected &&
      _connectionState != DeviceConnectionState.connectionLost;

  @override
  void initState() {
    super.initState();
    _platform = widget.platform ?? UnifiedDevicePlatform.instance;
    _client = UnifiedDeviceClient(
      UnifiedDeviceClientConfig(
        transport: BleTransport(platform: _platform),
        logMode: UcpLogMode.raw,
      ),
    );
    _subscriptions = <StreamSubscription<dynamic>>[
      _client.discoveredDevices.listen(_handleDevice),
      _client.connectionState.listen(_handleConnectionState),
      _client.communicationLogs.listen(_handleCommunicationLog),
    ];
    unawaited(_refreshBluetoothStatus());
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    if (!_transferredClientOwnership) {
      unawaited(_client.dispose());
    }
    super.dispose();
  }

  Future<void> _refreshBluetoothStatus() async {
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
      _bluetoothAvailable = values[1] as bool?;
      _bluetoothEnabled = values[2] as bool?;
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await _platform.requestBluetoothPermissions();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionsGranted = granted;
    });
    await _refreshBluetoothStatus();
  }

  Future<void> _toggleScan() async {
    if (_client.isScanning) {
      await _client.stopScan();
      _addActivity('Scan stopped');
      return;
    }

    setState(() {
      _devices.clear();
      _selectedDeviceId = null;
    });
    await _client.startScan();
    _addActivity(
      'Scan started for ${BleConstants.defaultDeviceName} / ${BleConstants.deviceService}',
    );
  }

  Future<void> _connectSelected() async {
    final device = _selectedDevice;
    if (device == null) {
      return;
    }
    await _runAction('Connect', () => _client.connect(device));
  }

  Future<void> _disconnect() async {
    await _runAction('Disconnect', _client.disconnect, allowWhileBusy: true);
  }

  Future<void> _retryBootstrap() async {
    await _runAction('Retry bootstrap', () async {
      await _client.sessionManager.bootstrap();
      await _client.sessionManager.waitUntilSessionActive();
    });
  }

  Future<void> _runAction(
    String label,
    Future<void> Function() action, {
    bool allowWhileBusy = false,
  }) async {
    if (_busy && !allowWhileBusy) {
      return;
    }
    setState(() {
      _pendingActions++;
    });
    try {
      await action();
    } on Object catch (error) {
      _addActivity('$label failed: ${_friendlyError(error)}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label failed: ${_friendlyError(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingActions--;
        });
      }
    }
  }

  void _handleDevice(DiscoveredDevice device) {
    if (!_isTargetDevice(device)) {
      return;
    }
    setState(() {
      _devices[device.deviceId] = device;
      _selectedDeviceId ??= device.deviceId;
    });
  }

  void _handleConnectionState(DeviceConnectionState state) {
    setState(() {
      _connectionState = state;
      _reachedStates.add(state);
      if (state == DeviceConnectionState.disconnected ||
          state == DeviceConnectionState.connectionLost) {
        _selectedDeviceId = null;
      }
    });
    _addActivity('State: ${_stateLabel(state)}');

    if (state == DeviceConnectionState.sessionActive &&
        !_navigatingToSoilTest) {
      _navigatingToSoilTest = true;
      unawaited(_openSoilTestScreen());
    }
  }

  void _handleCommunicationLog(DeviceCommunicationLog log) {
    final event = log.param['event'] as String?;
    if (event == null) {
      return;
    }
    if (event == 'command_result' || event == 'event_received') {
      return;
    }
    _addActivity('SDK: $event');
  }

  Future<void> _openSoilTestScreen() async {
    if (_client.isScanning) {
      await _client.stopScan();
    }
    if (!mounted) {
      return;
    }
    _transferredClientOwnership = true;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            SoilTestScreen(client: _client, disposeClientOnExit: true),
      ),
    );
  }

  bool _isTargetDevice(DiscoveredDevice device) {
    final matchesName = device.name == BleConstants.defaultDeviceName;
    final matchesService = device.serviceUuids.any(
      (uuid) => uuid.toUpperCase().contains(BleConstants.deviceService),
    );
    return matchesName || matchesService;
  }

  void _addActivity(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _activityLines.insert(0, message);
      if (_activityLines.length > _maxActivityLines) {
        _activityLines.removeLast();
      }
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  String _stateLabel(DeviceConnectionState state) {
    return switch (state) {
      DeviceConnectionState.disconnected => 'Disconnected',
      DeviceConnectionState.scanning => 'Scanning',
      DeviceConnectionState.connecting => 'Connecting',
      DeviceConnectionState.connected => 'Connected',
      DeviceConnectionState.servicesDiscovered => 'Services discovered',
      DeviceConnectionState.notifySubscribed => 'Notify subscribed',
      DeviceConnectionState.mtuReady => 'MTU ready',
      DeviceConnectionState.transportReady => 'Transport ready',
      DeviceConnectionState.sessionActive => 'Session active',
      DeviceConnectionState.measurementActive => 'Measurement active',
      DeviceConnectionState.streamActive => 'Stream active',
      DeviceConnectionState.safeDisconnectPending => 'Safe disconnect pending',
      DeviceConnectionState.disconnecting => 'Disconnecting',
      DeviceConnectionState.error => 'Error',
      DeviceConnectionState.connectionLost => 'Connection lost',
    };
  }

  bool _stepReached(DeviceConnectionState state) {
    if (_connectionState == DeviceConnectionState.sessionActive) {
      return true;
    }
    return _reachedStates.contains(state);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soil Test Connection'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConnectionStatusBar(
            connectionState: _connectionState,
            sessionReady: _client.isSessionActive,
            platformVersion: _platformVersion,
            bluetoothAvailable: _bluetoothAvailable,
            bluetoothEnabled: _bluetoothEnabled,
            permissionsGranted: _permissionsGranted,
          ),
          const SizedBox(height: 16),
          _buildIntroCard(),
          const SizedBox(height: 16),
          _buildConnectionActionsCard(),
          const SizedBox(height: 16),
          _buildDeviceListCard(),
          const SizedBox(height: 16),
          _buildActivityCard(),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Try Soil Test',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Use this flow to scan hardware, bootstrap the BLE/UCP session, '
              'and continue directly into the soil test demo.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connection Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _refreshBluetoothStatus,
                  child: const Text('Refresh Status'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _requestPermissions,
                  child: const Text('Request Permissions'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _toggleScan,
                  child: Text(_client.isScanning ? 'Stop Scan' : 'Scan'),
                ),
                OutlinedButton(
                  onPressed: _busy || !_canConnect ? null : _connectSelected,
                  child: const Text('Connect'),
                ),
                OutlinedButton(
                  onPressed: !_canDisconnect ? null : _disconnect,
                  child: const Text('Disconnect'),
                ),
                OutlinedButton(
                  onPressed:
                      _busy ||
                          _client.isSessionActive ||
                          _connectionState != DeviceConnectionState.connected
                      ? null
                      : _retryBootstrap,
                  child: const Text('Retry Bootstrap'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDeviceListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Devices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_devices.isEmpty)
              const Text('No matching Aunkur_UCP1 / FFE0 devices yet.')
            else
              ..._devices.values.map((device) {
                final selected = device.deviceId == _selectedDeviceId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    setState(() {
                      _selectedDeviceId = device.deviceId;
                    });
                  },
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(device.name ?? BleConstants.defaultDeviceName),
                  subtitle: Text('${device.deviceId}  RSSI ${device.rssi}'),
                  selected: selected,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_activityLines.isEmpty)
              const Text('No activity yet.')
            else
              ..._activityLines.map(Text.new),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStep {
  final DeviceConnectionState state;
  final String title;
  final String subtitle;

  const _ConnectionStep({
    required this.state,
    required this.title,
    required this.subtitle,
  });
}
