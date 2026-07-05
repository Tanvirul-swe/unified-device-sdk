import Foundation
import CoreBluetooth
import Flutter

struct NativeErrorMapper {
    static func flutterError(code: String, message: String, details: Any? = nil) -> FlutterError {
        FlutterError(code: code, message: message, details: details)
    }

    static func bluetoothStateError(for state: CBManagerState) -> FlutterError {
        switch state {
        case .poweredOff:
            return flutterError(
                code: BleConstants.bluetoothDisabledError,
                message: "Bluetooth is disabled"
            )
        case .unauthorized:
            return flutterError(
                code: BleConstants.permissionDeniedError,
                message: "Bluetooth permission denied"
            )
        case .unsupported:
            return flutterError(
                code: BleConstants.bluetoothUnavailableError,
                message: "Bluetooth is unavailable on this device"
            )
        case .resetting:
            return flutterError(
                code: BleConstants.bluetoothUnavailableError,
                message: "Bluetooth is resetting"
            )
        case .unknown:
            return flutterError(
                code: BleConstants.bluetoothUnavailableError,
                message: "Bluetooth state is unknown"
            )
        @unknown default:
            return flutterError(
                code: BleConstants.unknownError,
                message: "Unknown Bluetooth state"
            )
        }
    }

    static func centralError(code: String, message: String, error: Error? = nil) -> FlutterError {
        flutterError(
            code: code,
            message: message,
            details: error.map { String(describing: $0) }
        )
    }

    static func connectionEvent(
        state: String,
        deviceId: String?,
        message: String? = nil
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "state": state,
            "deviceId": deviceId ?? NSNull()
        ]

        if let message = message {
            payload["message"] = message
        }

        return payload
    }

    static func scanEvent(
        deviceId: String,
        name: String?,
        rssi: Int,
        serviceUuids: [String],
        manufacturerData: Data?
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "id": deviceId,
            "deviceId": deviceId,
            "name": name ?? NSNull(),
            "rssi": rssi,
            "serviceUuids": serviceUuids
        ]

        if let manufacturerData = manufacturerData {
            payload["manufacturerData"] = FlutterStandardTypedData(bytes: manufacturerData)
        }

        return payload
    }

    static func notificationEvent(data: Data) -> [String: Any] {
        [
            "data": FlutterStandardTypedData(bytes: data)
        ]
    }
}
