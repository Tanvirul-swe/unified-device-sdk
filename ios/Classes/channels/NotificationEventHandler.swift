import Foundation
import Flutter

final class NotificationEventHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func emit(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }

    func emitError(_ error: FlutterError) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(error)
        }
    }

    func clear() {
        eventSink = nil
    }
}
