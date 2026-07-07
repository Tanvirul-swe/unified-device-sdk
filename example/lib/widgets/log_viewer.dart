import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';

class LogViewer extends StatelessWidget {
  final List<LogEntry> logEntries;

  const LogViewer({
    super.key,
    required this.logEntries,
  });

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return const Color(0xFF1565C0);
      case LogLevel.success:
        return const Color(0xFF2E7D32);
      case LogLevel.error:
        return Colors.red.shade700;
      case LogLevel.state:
        return const Color(0xFF6A1B9A);
      case LogLevel.event:
        return const Color(0xFFE65100);
      case LogLevel.stream:
        return const Color(0xFF00838F);
    }
  }

  IconData _levelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.success:
        return Icons.check_circle_outline;
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.state:
        return Icons.sync;
      case LogLevel.event:
        return Icons.notifications_active_outlined;
      case LogLevel.stream:
        return Icons.leaderboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (logEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No logs yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Perform commands to see log output',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: logEntries.length,
      itemBuilder: (context, index) {
        final entry = logEntries[index];
        return _buildLogEntry(entry);
      },
    );
  }

  Widget _buildLogEntry(LogEntry entry) {
    final color = _levelColor(entry.level);
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_levelIcon(entry.level), size: 12, color: color),
                const SizedBox(width: 2),
                Text(
                  entry.level.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Message
          Expanded(
            child: SelectableText(
              entry.message,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}