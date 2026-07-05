/// Represents a device discovered during scanning.
///
/// Instances are immutable. Use [copyWith] to create updated copies.
class DiscoveredDevice {
  /// The unique identifier of the device (MAC address on Android, UUID on iOS).
  final String deviceId;

  /// The advertised name of the device, if available.
  final String? name;

  /// The RSSI (signal strength) value in dBm.
  final int rssi;

  /// The manufacturer-specific advertisement data, if available.
  final List<int>? manufacturerData;

  /// The list of service UUIDs advertised by the device.
  final List<String> serviceUuids;

  /// The time when the device was first discovered during the current scan.
  final DateTime firstDiscoveredAt;

  /// The time when the device was last seen during the current scan.
  final DateTime lastSeenAt;

  /// The number of times this device has been seen during the current scan.
  final int advertisementCount;

  /// Creates a [DiscoveredDevice].
  DiscoveredDevice({
    required this.deviceId,
    this.name,
    required this.rssi,
    this.manufacturerData,
    this.serviceUuids = const [],
    DateTime? firstDiscoveredAt,
    DateTime? lastSeenAt,
    this.advertisementCount = 1,
  })  : firstDiscoveredAt = firstDiscoveredAt ?? DateTime.now(),
        lastSeenAt = lastSeenAt ?? DateTime.now();

  /// Creates a copy with updated advertisement data.
  DiscoveredDevice copyWith({
    String? deviceId,
    String? name,
    int? rssi,
    List<int>? manufacturerData,
    List<String>? serviceUuids,
    DateTime? firstDiscoveredAt,
    DateTime? lastSeenAt,
    int? advertisementCount,
  }) {
    return DiscoveredDevice(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      manufacturerData: manufacturerData ?? this.manufacturerData,
      serviceUuids: serviceUuids ?? this.serviceUuids,
      firstDiscoveredAt: firstDiscoveredAt ?? this.firstDiscoveredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      advertisementCount: advertisementCount ?? this.advertisementCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() {
    return 'DiscoveredDevice(id: $deviceId, name: $name, rssi: $rssi dBm)';
  }
}