import 'dart:async';

import 'device_response.dart';
import '../../protocol/commands/command_options.dart';

/// Tracks a command request that is awaiting a response.
class PendingRequest {
  /// Sequence number used to correlate frames.
  final int sequence;

  /// Product identifier of the original command.
  final int productId;

  /// Device address of the original command.
  final int address;

  /// Command identifier of the original command.
  final int commandId;

  /// Operation code of the original command.
  final int op;

  /// Flags sent with the original command.
  final int flags;

  /// Raw command payload, if retained.
  final List<int> payload;

  /// Generic command execution options.
  final CommandOptions options;

  /// Completer resolved when the request finishes.
  final Completer<DeviceResponse> completer;

  /// Time the request was created.
  final DateTime createdAt;

  /// Whether a matching ACK has been received.
  bool ackReceived = false;

  /// The most recent ACK response, if any.
  DeviceResponse? ackResponse;

  Timer? _ackTimer;
  Timer? _dataTimer;

  PendingRequest({
    required this.sequence,
    required this.productId,
    required this.address,
    required this.commandId,
    required this.op,
    this.flags = 0,
    List<int> payload = const [],
    this.options = const CommandOptions(),
    Completer<DeviceResponse>? completer,
    DateTime? createdAt,
  })  : payload = List<int>.unmodifiable(payload),
        completer = completer ?? Completer<DeviceResponse>(),
        createdAt = createdAt ?? DateTime.now();

  /// Legacy alias retained for older call sites.
  int get sequenceNumber => sequence;

  /// Future resolved from [completer].
  Future<DeviceResponse> get future => completer.future;

  /// Whether the request has already completed.
  bool get isCompleted => completer.isCompleted;

  /// Starts the ACK timeout timer if ACK waiting is enabled.
  void startAckTimeout(void Function(PendingRequest request) onTimeout) {
    _ackTimer?.cancel();
    if (!options.waitForAck) {
      return;
    }
    _ackTimer = Timer(options.ackTimeout, () {
      if (!isCompleted) {
        onTimeout(this);
      }
    });
  }

  /// Starts the DATA timeout timer if DATA waiting is enabled.
  void startDataTimeout(void Function(PendingRequest request) onTimeout) {
    _dataTimer?.cancel();
    if (!options.waitForData) {
      return;
    }
    _dataTimer = Timer(options.dataTimeout, () {
      if (!isCompleted) {
        onTimeout(this);
      }
    });
  }

  /// Marks this request as having received a matching ACK response.
  void markAckReceived(DeviceResponse response) {
    ackReceived = true;
    ackResponse = response;
    _ackTimer?.cancel();
    _ackTimer = null;
  }

  /// Backward-compatible single timeout helper.
  void startTimeout(void Function(PendingRequest request) onTimeout) {
    startAckTimeout(onTimeout);
  }

  /// Cancels all active timers.
  void cancelTimeouts() {
    _ackTimer?.cancel();
    _dataTimer?.cancel();
    _ackTimer = null;
    _dataTimer = null;
  }

  /// Backward-compatible timeout cancellation helper.
  void cancelTimeout() {
    cancelTimeouts();
  }

  /// Completes the request successfully.
  void complete(DeviceResponse response) {
    cancelTimeouts();
    if (!isCompleted) {
      completer.complete(response);
    }
  }

  /// Completes the request with an error.
  void completeError(Object error, [StackTrace? stackTrace]) {
    cancelTimeouts();
    if (!isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }
}
