import 'package:flutter/material.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

class DeviceScanPanel extends StatelessWidget {
  final List<DiscoveredDevice> devices;
  final String? selectedDeviceId;
  final bool isScanning;
  final bool canConnect;
  final bool canDisconnect;
  final VoidCallback onToggleScan;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final ValueChanged<String> onSelectDevice;
  final VoidCallback? onRetryBootstrap;

  const DeviceScanPanel({
    super.key,
    required this.devices,
    required this.selectedDeviceId,
    required this.isScanning,
    required this.canConnect,
    required this.canDisconnect,
    required this.onToggleScan,
    required this.onConnect,
    required this.onDisconnect,
    required this.onSelectDevice,
    this.onRetryBootstrap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.bluetooth_searching, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Device Discovery',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isScanning)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onToggleScan,
                    icon: Icon(isScanning ? Icons.stop : Icons.search),
                    label: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canConnect ? onConnect : null,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canDisconnect ? onDisconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: canDisconnect ? Colors.red.shade700 : null,
                      side: canDisconnect
                          ? BorderSide(color: Colors.red.shade300)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Device list
            if (devices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isScanning
                          ? 'Searching for devices...'
                          : 'No devices found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (!isScanning)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Tap "Start Scan" to discover nearby devices',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              ...devices.map(
                (device) => _buildDeviceTile(context, device),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BuildContext context, DiscoveredDevice device) {
    final isSelected = device.deviceId == selectedDeviceId;
    final rssiColor = _rssiColor(device.rssi);
    final rssiLabel = '${device.rssi} dBm';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelectDevice(device.deviceId),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // RSSI indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: rssiColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.signal_cellular_alt,
                      color: rssiColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name ?? BleConstants.defaultDeviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device.deviceId,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                // RSSI value
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rssiColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rssiLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: rssiColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 18, color: Theme.of(context).colorScheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _rssiColor(int? rssi) {
    if (rssi == null) return Colors.grey;
    if (rssi >= -60) return const Color(0xFF2E7D32);
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }
}