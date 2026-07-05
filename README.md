# unified_device_sdk

Flutter plugin for raw BLE transport to unified devices.

## iOS Setup

The consuming iOS app must include:

- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription` for older iOS compatibility

Example:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan for and connect to supported BLE devices.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to communicate with supported BLE devices.</string>
```
