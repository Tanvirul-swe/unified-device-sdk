/// Logger for the Unified Device SDK.
///
/// Provides configurable logging with different severity levels.
class UnifiedDeviceLogger {
  /// Whether debug logging is enabled.
  bool debugEnabled;

  /// Tag prefix for log messages.
  final String tag;

  /// Creates a [UnifiedDeviceLogger] with the given tag and settings.
  UnifiedDeviceLogger({
    this.tag = 'UnifiedDeviceSDK',
    this.debugEnabled = false,
  });

  /// Logs a debug message.
  void debug(String message) {
    if (debugEnabled) {
      _log('DEBUG', message);
    }
  }

  /// Logs an informational message.
  void info(String message) {
    _log('INFO', message);
  }

  /// Logs a warning message.
  void warning(String message) {
    _log('WARNING', message);
  }

  /// Logs an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message);
    if (error != null) {
      _log('ERROR', 'Error details: $error');
    }
    if (stackTrace != null) {
      _log('ERROR', 'Stack trace: $stackTrace');
    }
  }

  void _log(String level, String message) {
    // ignore: avoid_print
    print('[$tag] [$level] $message');
  }
}

/// Default logger instance for the SDK.
final UnifiedDeviceLogger log = UnifiedDeviceLogger();
