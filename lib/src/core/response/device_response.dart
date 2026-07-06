import '../frame/device_frame.dart';
import '../../protocol/constants/command_classes.dart';
import '../../protocol/constants/operation_codes.dart';
import '../../protocol/constants/profile_ids.dart';
import '../../protocol/constants/ucp_addresses.dart';

/// Generic response model derived from a device frame.
class DeviceResponse {
  /// Request/response correlation sequence.
  final int sequence;

  /// Product identifier from the frame header.
  final int productId;

  final int profileId;
  final int sourceAddress;
  final int destinationAddress;

  /// Command identifier from the frame header.
  final int commandId;

  /// Operation code from the frame header.
  final int op;

  final int commandClass;

  /// Flags byte from the frame header.
  final int flags;

  /// Raw response payload bytes.
  final List<int> payload;

  /// Source frame used to derive this response, when available.
  final DeviceFrame? sourceFrame;

  /// Optional generic error message for failed responses.
  final String? errorMessage;

  /// Timestamp when the response model was created.
  final DateTime receivedAt;

  DeviceResponse({
    required this.sequence,
    required this.productId,
    this.profileId = ProfileIds.defaultProfile,
    this.sourceAddress = UcpAddresses.defaultSource,
    int? address,
    int? destinationAddress,
    required this.commandId,
    required this.op,
    this.commandClass = CommandClasses.system,
    required this.flags,
    required List<int> payload,
    this.sourceFrame,
    this.errorMessage,
    DateTime? receivedAt,
  }) : destinationAddress =
           destinationAddress ?? address ?? UcpAddresses.defaultDestination,
       payload = List<int>.unmodifiable(payload),
       receivedAt = receivedAt ?? DateTime.now();

  int get address => destinationAddress;

  /// Creates a [DeviceResponse] from a parsed frame.
  factory DeviceResponse.fromFrame(
    DeviceFrame frame, {
    String? errorMessage,
    DateTime? receivedAt,
  }) {
    return DeviceResponse(
      sequence: frame.sequence,
      productId: frame.productId,
      profileId: frame.profileId,
      sourceAddress: frame.sourceAddress,
      destinationAddress: frame.destinationAddress,
      commandId: frame.commandId,
      op: frame.op,
      commandClass: frame.commandClass,
      flags: frame.flags,
      payload: frame.payload,
      sourceFrame: frame,
      errorMessage: errorMessage,
      receivedAt: receivedAt,
    );
  }

  /// Legacy alias retained for older call sites.
  int get sequenceNumber => sequence;

  /// Legacy alias retained for older call sites.
  int get statusCode => flags;

  /// Whether the operation is a negative acknowledgment.
  bool get isNack => op == OperationCodes.nack;

  /// Whether the operation is an acknowledgment.
  bool get isAck => op == OperationCodes.ack;

  /// Whether the response indicates success.
  bool get isSuccess => !isNack;

  /// Creates a success response without requiring a source frame.
  factory DeviceResponse.success({
    required int sequence,
    int productId = 0,
    int profileId = ProfileIds.defaultProfile,
    int sourceAddress = UcpAddresses.defaultSource,
    int address = UcpAddresses.defaultDestination,
    int? destinationAddress,
    required int commandId,
    int op = OperationCodes.ack,
    int commandClass = CommandClasses.system,
    int flags = 0,
    List<int> payload = const [],
    DeviceFrame? sourceFrame,
    DateTime? receivedAt,
  }) {
    return DeviceResponse(
      sequence: sequence,
      productId: productId,
      profileId: profileId,
      sourceAddress: sourceAddress,
      destinationAddress: destinationAddress ?? address,
      commandId: commandId,
      op: op,
      commandClass: commandClass,
      flags: flags,
      payload: payload,
      sourceFrame: sourceFrame,
      receivedAt: receivedAt,
    );
  }

  /// Creates a failure response without requiring a source frame.
  factory DeviceResponse.failure({
    required int sequence,
    int productId = 0,
    int profileId = ProfileIds.defaultProfile,
    int sourceAddress = UcpAddresses.defaultSource,
    int address = UcpAddresses.defaultDestination,
    int? destinationAddress,
    required int commandId,
    int op = OperationCodes.nack,
    int commandClass = CommandClasses.system,
    int flags = 0,
    List<int> payload = const [],
    String? errorMessage,
    DeviceFrame? sourceFrame,
    DateTime? receivedAt,
  }) {
    return DeviceResponse(
      sequence: sequence,
      productId: productId,
      profileId: profileId,
      sourceAddress: sourceAddress,
      destinationAddress: destinationAddress ?? address,
      commandId: commandId,
      op: op,
      commandClass: commandClass,
      flags: flags,
      payload: payload,
      sourceFrame: sourceFrame,
      errorMessage: errorMessage,
      receivedAt: receivedAt,
    );
  }

  /// Backward-compatible success factory.
  factory DeviceResponse.legacySuccess({
    required int sequenceNumber,
    required List<int> payload,
    int? statusCode,
  }) {
    return DeviceResponse.success(
      sequence: sequenceNumber,
      commandId: 0,
      flags: statusCode ?? 0,
      payload: payload,
    );
  }

  /// Backward-compatible failure factory.
  factory DeviceResponse.legacyFailure({
    required int sequenceNumber,
    String? errorMessage,
    int? statusCode,
    List<int> payload = const [],
  }) {
    return DeviceResponse.failure(
      sequence: sequenceNumber,
      commandId: 0,
      flags: statusCode ?? 0,
      payload: payload,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    return 'DeviceResponse('
        'seq: $sequence, '
        'productId: 0x${productId.toRadixString(16).toUpperCase()}, '
        'address: 0x${address.toRadixString(16).toUpperCase()}, '
        'commandId: 0x${commandId.toRadixString(16).toUpperCase()}, '
        'op: 0x${op.toRadixString(16).toUpperCase()}, '
        'flags: 0x${flags.toRadixString(16).toUpperCase()}, '
        'payload: [${payload.length} bytes])';
  }
}
