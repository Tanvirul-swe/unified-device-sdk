import 'package:flutter/material.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

class ConnectionStatusBar extends StatelessWidget {
  final DeviceConnectionState connectionState;
  final bool sessionReady;
  final String? platformVersion;
  final bool? bluetoothAvailable;
  final bool? bluetoothEnabled;
  final bool? permissionsGranted;

  const ConnectionStatusBar({
    super.key,
    required this.connectionState,
    required this.sessionReady,
    this.platformVersion,
    this.bluetoothAvailable,
    this.bluetoothEnabled,
    this.permissionsGranted,
  });

  Color _statusColor() {
    if (sessionReady) return const Color(0xFF2E7D32);
    switch (connectionState) {
      case DeviceConnectionState.connected:
      case DeviceConnectionState.servicesDiscovered:
      case DeviceConnectionState.notifySubscribed:
      case DeviceConnectionState.mtuReady:
      case DeviceConnectionState.transportReady:
        return const Color(0xFF1565C0);
      case DeviceConnectionState.connecting:
      case DeviceConnectionState.disconnecting:
        return Colors.orange;
      case DeviceConnectionState.scanning:
        return Colors.blue.shade300;
      case DeviceConnectionState.connectionLost:
      case DeviceConnectionState.error:
        return Colors.red;
      case DeviceConnectionState.disconnected:
        return Colors.grey;
      case DeviceConnectionState.sessionActive:
      case DeviceConnectionState.measurementActive:
      case DeviceConnectionState.streamActive:
        return const Color(0xFF2E7D32);
      case DeviceConnectionState.safeDisconnectPending:
        return Colors.orange.shade800;
    }
  }

  String _statusLabel() {
    if (sessionReady) return 'Session Active';
    switch (connectionState) {
      case DeviceConnectionState.disconnected:
        return 'Disconnected';
      case DeviceConnectionState.scanning:
        return 'Scanning...';
      case DeviceConnectionState.connecting:
        return 'Connecting...';
      case DeviceConnectionState.connected:
        return 'Connected';
      case DeviceConnectionState.servicesDiscovered:
        return 'Services Discovered';
      case DeviceConnectionState.notifySubscribed:
        return 'Notifying';
      case DeviceConnectionState.mtuReady:
        return 'MTU Ready';
      case DeviceConnectionState.transportReady:
        return 'Transport Ready';
      case DeviceConnectionState.sessionActive:
        return 'Session Active';
      case DeviceConnectionState.measurementActive:
        return 'Measuring';
      case DeviceConnectionState.streamActive:
        return 'Streaming';
      case DeviceConnectionState.safeDisconnectPending:
        return 'Safe Disconnect...';
      case DeviceConnectionState.disconnecting:
        return 'Disconnecting...';
      case DeviceConnectionState.error:
        return 'Error';
      case DeviceConnectionState.connectionLost:
        return 'Connection Lost';
    }
  }

  IconData _statusIcon() {
    if (sessionReady) return Icons.check_circle;
    switch (connectionState) {
      case DeviceConnectionState.disconnected:
        return Icons.link_off;
      case DeviceConnectionState.scanning:
        return Icons.bluetooth_searching;
      case DeviceConnectionState.connecting:
        return Icons.bluetooth_connected;
      case DeviceConnectionState.connected:
        return Icons.bluetooth_connected;
      case DeviceConnectionState.servicesDiscovered:
        return Icons.view_list;
      case DeviceConnectionState.notifySubscribed:
        return Icons.sync;
      case DeviceConnectionState.mtuReady:
      case DeviceConnectionState.transportReady:
        return Icons.settings_ethernet;
      case DeviceConnectionState.sessionActive:
        return Icons.check_circle;
      case DeviceConnectionState.measurementActive:
        return Icons.science;
      case DeviceConnectionState.streamActive:
        return Icons.leaderboard;
      case DeviceConnectionState.safeDisconnectPending:
        return Icons.logout;
      case DeviceConnectionState.disconnecting:
        return Icons.bluetooth_disabled;
      case DeviceConnectionState.error:
      case DeviceConnectionState.connectionLost:
        return Icons.warning_amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main status row
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(_statusIcon(), size: 20, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                if (sessionReady)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.vpn_key, size: 14, color: Color(0xFF2E7D32)),
                        SizedBox(width: 4),
                        Text(
                          'BOOTSTRAPPED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Status details grid
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _statusChip(
                  Icons.bluetooth,
                  'BT',
                  bluetoothAvailable == true && bluetoothEnabled == true
                      ? 'ON'
                      : bluetoothAvailable == false
                          ? 'N/A'
                          : 'OFF',
                  bluetoothAvailable == true && bluetoothEnabled == true
                      ? const Color(0xFF2E7D32)
                      : Colors.grey,
                ),
                _statusChip(
                  Icons.shield_outlined,
                  'Perms',
                  permissionsGranted == true
                      ? 'Granted'
                      : permissionsGranted == false
                          ? 'Denied'
                          : '--',
                  permissionsGranted == true
                      ? const Color(0xFF2E7D32)
                      : permissionsGranted == false
                          ? Colors.red
                          : Colors.grey,
                ),
                _statusChip(
                  Icons.phone_android,
                  'SDK',
                  platformVersion ?? '--',
                  theme.colorScheme.primary,
                ),
                _statusChip(
                  Icons.sensors,
                  'BLE',
                  bluetoothEnabled == true ? 'Enabled' : 'Disabled',
                  bluetoothEnabled == true
                      ? const Color(0xFF2E7D32)
                      : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}