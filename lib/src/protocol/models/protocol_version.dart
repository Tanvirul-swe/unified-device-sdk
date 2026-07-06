/// Represents the protocol version supported by a device.
class ProtocolVersion {
  /// Major version number.
  final int major;

  /// Minor version number.
  final int minor;

  /// Patch version number.
  final int patch;

  const ProtocolVersion({
    required this.major,
    required this.minor,
    this.patch = 0,
  });

  /// Returns true if this version is compatible with [other].
  bool isCompatibleWith(ProtocolVersion other) {
    return major == other.major && minor == other.minor;
  }

  /// Whether this version is at least the specified version.
  bool isAtLeast(
    int requiredMajor,
    int requiredMinor, [
    int requiredPatch = 0,
  ]) {
    if (major > requiredMajor) return true;
    if (major < requiredMajor) return false;
    if (minor > requiredMinor) return true;
    if (minor < requiredMinor) return false;
    return patch >= requiredPatch;
  }

  /// Returns the version as a formatted string.
  String get formattedVersion => '$major.$minor.$patch';

  @override
  String toString() => 'ProtocolVersion($formattedVersion)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProtocolVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}
