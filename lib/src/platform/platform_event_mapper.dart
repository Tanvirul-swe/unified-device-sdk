/// Maps raw event maps from native platform channels into strongly-typed
/// Dart maps with consistent key naming and default values.
///
/// The native layers (Android/iOS) emit events as `Map<String, dynamic>`
/// through Flutter event channels. This mapper normalizes those maps so
/// that higher layers can consume them with predictable structure.
///
/// ## Expected Native Event Map Structures
///
/// ### Scan Result
/// ```json
/// {
///   "deviceId": "AA:BB:CC:DD:EE:FF",
///   "name": "My Device",
///   "rssi": -60,
///   "manufacturerData": "base64...",
///   "serviceUuids": ["0000ffe0-..."]
/// }
/// ```
///
/// ### Connection State
/// ```json
/// {
///   "state": "connected",
///   "deviceId": "AA:BB:CC:DD:EE:FF"
/// }
/// ```
/// Valid state values: `connecting`, `connected`, `disconnecting`,
/// `disconnected`, `connectionLost`.
///
/// ### Notification Data
/// ```json
/// {
///   "data": "base64EncodedBytes..."
/// }
/// ```
///
/// ### Error
/// ```json
/// {
///   "code": "ERROR_CODE",
///   "message": "Human-readable error message",
///   "details": {}
/// }
/// ```
class PlatformEventMapper {
  PlatformEventMapper._();

  /// Maps a native scan result map to a normalized form.
  ///
  /// All keys are guaranteed to be present with non-null defaults.
  static Map<String, dynamic> mapScanResult(Map<String, dynamic> native) {
    return {
      'deviceId':
          native['deviceId'] as String? ?? native['id'] as String? ?? '',
      'name': native['name'] as String?,
      'rssi': native['rssi'] as int? ?? 0,
      'manufacturerData': native['manufacturerData'],
      'serviceUuids':
          (native['serviceUuids'] as List<dynamic>?)?.cast<String>() ??
          <String>[],
    };
  }

  /// Maps a native connection state map to a normalized form.
  ///
  /// [state] defaults to `'disconnected'` if not present or invalid.
  static Map<String, dynamic> mapConnectionState(Map<String, dynamic> native) {
    return {
      'state': native['state'] as String? ?? 'disconnected',
      'deviceId': native['deviceId'] as String? ?? native['id'] as String?,
      'message': native['message'] as String?,
    };
  }

  /// Maps a native notification data map to a normalized form.
  ///
  /// [data] is a base64-encoded string of the received bytes.
  static Map<String, dynamic> mapNotificationData(Map<String, dynamic> native) {
    return {'data': native['data']};
  }

  /// Maps a native error map to a normalized form.
  ///
  /// [code] defaults to `'UNKNOWN'` if not present.
  static Map<String, dynamic> mapError(Map<String, dynamic> native) {
    return {
      'code': native['code'] as String? ?? 'UNKNOWN',
      'message': native['message'] as String? ?? 'Unknown error',
      'details': native['details'],
    };
  }
}
