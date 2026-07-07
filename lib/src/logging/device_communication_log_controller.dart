import 'dart:async';

import 'device_communication_log.dart';

/// Lightweight broadcast controller for SDK communication logs.
class DeviceCommunicationLogController {
  final StreamController<DeviceCommunicationLog> _controller =
      StreamController<DeviceCommunicationLog>.broadcast();

  Stream<DeviceCommunicationLog> get stream => _controller.stream;

  void add(DeviceCommunicationLog log) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(log);
  }

  Future<void> dispose() async {
    if (_controller.isClosed) {
      return;
    }
    await _controller.close();
  }
}
