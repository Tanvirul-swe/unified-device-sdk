import '../bytes/endian_utils.dart';
import '../../protocol/constants/operation_codes.dart';

/// Represents a complete device communication frame (logical content).
///
/// Frame wire format (SOF and EOF are protocol-level delimiters, not stored here):
///   VER(1) PRODUCT(2) ADDR(4) OP(1) CMD(1) SEQ(1) FLAGS(1) LEN_H(1) LEN_L(1) PAYLOAD(n) CRC_H(1) CRC_L(1)
///
/// This class holds the logical fields. The [payloadLength] is computed from
/// the payload list length. Helper booleans ([isAck], [isNack], etc.) provide
/// convenient access to the operation type.
///
/// All fields are validated on construction. The payload list is defensively
/// copied to prevent external mutation.
class DeviceFrame {
  /// Protocol version byte (0-255).
  final int version;

  /// Product identifier (0-65535).
  final int productId;

  /// Device address as a 32-bit unsigned integer (0-4294967295).
  /// Typically a BLE MAC address or custom device ID.
  final int address;

  /// Operation code — determines the type of operation (READ, WRITE, etc.).
  /// See [OperationCodes] for valid values.
  final int op;

  /// Command identifier — interpreted in the context of [op].
  /// For example, OP=READ + CMD=readDeviceInfo means "read device info".
  final int commandId;

  /// Sequence number for request-response matching (1-255 by default).
  final int sequence;

  /// Frame flags bitfield — see [ProtocolFlags] for bit definitions.
  final int flags;

  /// The payload data bytes (0-65535 bytes, each 0-255).
  final List<int> payload;

  /// CRC-16 checksum of the frame (0-65535).
  final int crc;

  /// The minimum valid sequence number (inclusive).
  final int minSequence;

  /// The maximum valid sequence number (inclusive).
  final int maxSequence;

  // ---- Computed Properties ----

  /// Length of the payload in bytes (computed from [payload]).
  int get payloadLength => payload.length;

  /// Whether this frame is an ACK (acknowledgment) operation.
  bool get isAck => op == OperationCodes.ack;

  /// Whether this frame is a NACK (negative acknowledgment) operation.
  bool get isNack => op == OperationCodes.nack;

  /// Whether this frame is an EVENT (asynchronous notification) operation.
  bool get isEvent => op == OperationCodes.event;

  /// Whether this frame is a DATA (bulk transfer) operation.
  bool get isData => op == OperationCodes.data;

  /// Whether this frame is a READ operation.
  bool get isRead => op == OperationCodes.read;

  /// Whether this frame is a WRITE operation.
  bool get isWrite => op == OperationCodes.write;

  /// Whether this frame is an ACTION operation.
  bool get isAction => op == OperationCodes.action;

  /// Creates a [DeviceFrame] with the given fields.
  ///
  /// All one-byte fields are validated to be 0-255.
  /// [productId] is validated to be 0-65535.
  /// [address] is validated to be 0-4294967295.
  /// [crc] is validated to be 0-65535.
  /// [sequence] is validated to be within [minSequence]..[maxSequence].
  /// [payload] is defensively copied; each byte must be 0-255.
  /// Payload length must not exceed 65535.
  ///
  /// Throws [ArgumentError] if any validation fails.
  DeviceFrame({
    required this.version,
    required this.productId,
    required this.address,
    required this.op,
    required this.commandId,
    required this.sequence,
    required this.flags,
    required List<int> payload,
    required this.crc,
    this.minSequence = 1,
    this.maxSequence = 255,
  }) : payload = List.unmodifiable(payload) {
    _validateUint8(version, 'version');
    _validateUint16(productId, 'productId');
    _validateUint32(address, 'address');
    _validateUint8(op, 'op');
    _validateUint8(commandId, 'commandId');
    _validateSequence(sequence, minSequence, maxSequence);
    _validateUint8(flags, 'flags');
    _validatePayload(this.payload);
    _validateUint16(crc, 'crc');
  }

  /// Creates a copy of this frame with the given fields replaced.
  DeviceFrame copyWith({
    int? version,
    int? productId,
    int? address,
    int? op,
    int? commandId,
    int? sequence,
    int? flags,
    List<int>? payload,
    int? crc,
    int? minSequence,
    int? maxSequence,
  }) {
    return DeviceFrame(
      version: version ?? this.version,
      productId: productId ?? this.productId,
      address: address ?? this.address,
      op: op ?? this.op,
      commandId: commandId ?? this.commandId,
      sequence: sequence ?? this.sequence,
      flags: flags ?? this.flags,
      payload: payload ?? this.payload,
      crc: crc ?? this.crc,
      minSequence: minSequence ?? this.minSequence,
      maxSequence: maxSequence ?? this.maxSequence,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceFrame &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          productId == other.productId &&
          address == other.address &&
          op == other.op &&
          commandId == other.commandId &&
          sequence == other.sequence &&
          flags == other.flags &&
          _listEquals(payload, other.payload) &&
          crc == other.crc;

  @override
  int get hashCode => Object.hash(
        version,
        productId,
        address,
        op,
        commandId,
        sequence,
        flags,
        Object.hashAll(payload),
        crc,
      );

  /// Returns a human-readable summary of the frame.
  @override
  String toString() {
    return 'DeviceFrame('
        'ver: $version, '
        'product: 0x${productId.toRadixString(16).toUpperCase().padLeft(4, '0')}, '
        'addr: 0x${address.toRadixString(16).toUpperCase().padLeft(8, '0')}, '
        'op: 0x${op.toRadixString(16).toUpperCase().padLeft(2, '0')}, '
        'cmd: 0x${commandId.toRadixString(16).toUpperCase().padLeft(2, '0')}, '
        'seq: $sequence, '
        'flags: 0x${flags.toRadixString(16).toUpperCase().padLeft(2, '0')}, '
        'payload: [${payload.length} bytes], '
        'crc: 0x${crc.toRadixString(16).toUpperCase().padLeft(4, '0')})';
  }

  /// Returns a debug hex dump of the frame's logical content.
  ///
  /// Format: space-separated uppercase hex bytes representing the frame
  /// in wire order: VER PRODUCT ADDR OP CMD SEQ FLAGS LEN PAYLOAD CRC.
  String toHexString() {
    final bytes = <int>[
      version,
      ...EndianUtils.uint16ToBytesBE(productId),
      ...EndianUtils.uint32ToBytesBE(address),
      op,
      commandId,
      sequence,
      flags,
      ...EndianUtils.uint16ToBytesBE(payload.length),
      ...payload,
      ...EndianUtils.uint16ToBytesBE(crc),
    ];
    return EndianUtils.toHexString(bytes);
  }

  // ---- Validation ----

  static void _validateUint8(int value, String name) {
    if (value < 0 || value > 255) {
      throw ArgumentError(
        '$name must be 0-255, but got $value',
      );
    }
  }

  static void _validateUint16(int value, String name) {
    if (value < 0 || value > 65535) {
      throw ArgumentError(
        '$name must be 0-65535, but got $value',
      );
    }
  }

  static void _validateUint32(int value, String name) {
    if (value < 0 || value > 4294967295) {
      throw ArgumentError(
        '$name must be 0-4294967295, but got $value',
      );
    }
  }

  static void _validateSequence(int value, int min, int max) {
    if (value < min || value > max) {
      throw ArgumentError(
        'sequence must be $min-$max, but got $value',
      );
    }
  }

  static void _validatePayload(List<int> payload) {
    if (payload.length > 65535) {
      throw ArgumentError(
        'payload length must not exceed 65535, but got ${payload.length}',
      );
    }
    for (var i = 0; i < payload.length; i++) {
      if (payload[i] < 0 || payload[i] > 255) {
        throw ArgumentError(
          'payload byte at index $i must be 0-255, but got ${payload[i]}',
        );
      }
    }
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}