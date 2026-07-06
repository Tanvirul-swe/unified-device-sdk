/// Information about a device.
class DeviceInfo {
  /// The product identifier.
  final int productId;

  /// The hardware version.
  final int hardwareVersion;

  /// The serial number string.
  final String serialNumber;

  /// The manufacturer name.
  final String manufacturerName;

  /// The model name.
  final String modelName;

  const DeviceInfo({
    required this.productId,
    required this.hardwareVersion,
    required this.serialNumber,
    this.manufacturerName = '',
    this.modelName = '',
  });

  @override
  String toString() {
    return 'DeviceInfo(productId: 0x${productId.toRadixString(16).toUpperCase().padLeft(4, '0')}, '
        'hwVer: $hardwareVersion, '
        'serial: $serialNumber, '
        'manufacturer: $manufacturerName, '
        'model: $modelName)';
  }
}
