/// Information about device firmware.
class FirmwareInfo {
  /// Major version number.
  final int major;

  /// Minor version number.
  final int minor;

  /// Patch version number.
  final int patch;

  /// Build number.
  final int buildNumber;

  /// Human-readable version string, if available.
  final String versionString;

  const FirmwareInfo({
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
    this.versionString = '',
  });

  /// Returns the version as a formatted string: "major.minor.patch+build".
  String get formattedVersion => '$major.$minor.$patch+$buildNumber';

  @override
  String toString() {
    return 'FirmwareInfo($formattedVersion${versionString.isNotEmpty ? ' - $versionString' : ''})';
  }
}
