/// Immutable communication log entry emitted by the SDK.
class DeviceCommunicationLog {
  final String logId;
  final String sessionId;
  final String? deviceId;
  final String? deviceName;
  final int timestamp;
  final Map<String, dynamic> param;

  const DeviceCommunicationLog({
    required this.logId,
    required this.sessionId,
    this.deviceId,
    this.deviceName,
    required this.timestamp,
    required this.param,
  });

  DeviceCommunicationLog copyWith({
    String? logId,
    String? sessionId,
    String? deviceId,
    bool clearDeviceId = false,
    String? deviceName,
    bool clearDeviceName = false,
    int? timestamp,
    Map<String, dynamic>? param,
  }) {
    return DeviceCommunicationLog(
      logId: logId ?? this.logId,
      sessionId: sessionId ?? this.sessionId,
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      deviceName: clearDeviceName ? null : (deviceName ?? this.deviceName),
      timestamp: timestamp ?? this.timestamp,
      param: param ?? this.param,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'log_id': logId,
      'session_id': sessionId,
      'device_id': deviceId,
      'device_name': deviceName,
      'timestamp': timestamp,
      'param': param,
    };
  }

  factory DeviceCommunicationLog.fromJson(Map<String, dynamic> json) {
    return DeviceCommunicationLog(
      logId: json['log_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      deviceId: json['device_id'] as String?,
      deviceName: json['device_name'] as String?,
      timestamp: json['timestamp'] as int? ?? 0,
      param: Map<String, dynamic>.from(
        json['param'] as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  String toString() => 'DeviceCommunicationLog(${toJson()})';
}
