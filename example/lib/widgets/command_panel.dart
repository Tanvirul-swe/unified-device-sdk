import 'package:flutter/material.dart';

class CommandPanel extends StatelessWidget {
  final bool sessionReady;
  final bool streamActive;
  final bool busy;
  final VoidCallback onDeviceInfo;
  final VoidCallback onTime;
  final VoidCallback onStartTest;
  final VoidCallback onLastReport;
  final VoidCallback onMoistOn;
  final VoidCallback onMoistOff;
  final VoidCallback onFont;
  final VoidCallback onCdn;

  const CommandPanel({
    super.key,
    required this.sessionReady,
    required this.streamActive,
    required this.busy,
    required this.onDeviceInfo,
    required this.onTime,
    required this.onStartTest,
    required this.onLastReport,
    required this.onMoistOn,
    required this.onMoistOff,
    required this.onFont,
    required this.onCdn,
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
                Icon(Icons.terminal, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Device Commands',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!sessionReady)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Session required',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Info & Data section
            _buildSectionLabel(theme, 'Information & Data'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _commandButton(
                  context,
                  label: 'Device Info',
                  icon: Icons.info_outline,
                  enabled: sessionReady && !busy,
                  onPressed: onDeviceInfo,
                ),
                _commandButton(
                  context,
                  label: 'Read Time',
                  icon: Icons.access_time,
                  enabled: sessionReady && !busy,
                  onPressed: onTime,
                ),
                _commandButton(
                  context,
                  label: 'Last Report',
                  icon: Icons.assessment,
                  enabled: sessionReady && !busy,
                  onPressed: onLastReport,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Test section
            _buildSectionLabel(theme, 'Test & Measurement'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _commandButton(
                  context,
                  label: 'Start Test',
                  icon: Icons.play_arrow,
                  enabled: sessionReady && !busy,
                  onPressed: onStartTest,
                ),
                _commandButton(
                  context,
                  label: 'Moisture ON',
                  icon: Icons.water_drop,
                  enabled: sessionReady && !busy && !streamActive,
                  onPressed: onMoistOn,
                  color: const Color(0xFF1565C0),
                ),
                _commandButton(
                  context,
                  label: 'Moisture OFF',
                  icon: Icons.water_drop_outlined,
                  enabled: sessionReady && !busy && streamActive,
                  onPressed: onMoistOff,
                  color: Colors.orange.shade700,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // System section
            _buildSectionLabel(theme, 'System'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _commandButton(
                  context,
                  label: 'Font (English)',
                  icon: Icons.text_fields,
                  enabled: sessionReady && !busy,
                  onPressed: onFont,
                ),
                _commandButton(
                  context,
                  label: 'CDN',
                  icon: Icons.cloud_download,
                  enabled: sessionReady && !busy,
                  onPressed: onCdn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _commandButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Tooltip(
        message: enabled ? label : 'Session not ready',
        child: Material(
          color: enabled
              ? effectiveColor.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: enabled ? effectiveColor : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: enabled ? effectiveColor : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}