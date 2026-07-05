  private fun configureGattServices(gatt: BluetoothGatt) {
        val service: BluetoothGattService? = gatt.getService(SERVICE_UUID)
        if (service == null) {
            handleConnectionFailure(
                "service_not_found",
                "Required service FFE0 not found",
                mapOf("deviceId" to connectedDeviceId, "serviceUuid" to SERVICE_UUID.toString())
            )
            gatt.disconnect()
            return
        }

        val notify = service.getCharacteristic(NOTIFY_CHARACTERISTIC_UUID)
        val write = service.getCharacteristic(WRITE_CHARACTERISTIC_UUID)
        if (notify == null || write == null) {
            handleConnectionFailure(
                "characteristic_not_found",
                "Required FFE1/FFE2 characteristics were not found",
                mapOf(
                    "deviceId" to connectedDeviceId,
                    "notifyCharacteristicUuid" to NOTIFY_CHARACTERISTIC_UUID.toString(),
                    "writeCharacteristicUuid" to WRITE_CHARACTERISTIC_UUID.toString()
                )
            )
            gatt.disconnect()
            return
        }

        val notificationsEnabled = gatt.setCharacteristicNotification(notify, true)
        if (!notificationsEnabled) {
            handleConnectionFailure(
                "notification_enable_failed",
                "Failed to enable notifications on FFE1",
                mapOf("deviceId" to connectedDeviceId, "characteristicUuid" to NOTIFY_CHARACTERISTIC_UUID.toString())
            )
            gatt.disconnect()
            return
        }

        val cccd = notify.getDescriptor(CCCD_UUID)
        if (cccd == null) {
            handleConnectionFailure(
                "characteristic_not_found",
                "CCCD descriptor not found for FFE1",
                mapOf("deviceId" to connectedDeviceId, "descriptorUuid" to CCCD_UUID.toString())
            )
            gatt.disconnect()
            return
        }

        notifyCharacteristic = notify
        writeCharacteristic = write

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val status = gatt.writeDescriptor(cccd, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    handleConnectionFailure(
                        "notification_enable_failed",
                        "Failed to enable notifications (status=$status ${describeGattStatus(status)})",
                        mapOf(
                            "deviceId" to connectedDeviceId,
                            "status" to status,
                            "statusName" to describeGattStatus(status)
                        )
                    )
                    gatt.disconnect()
                }
            } else {
                @Suppress("DEPRECATION")
                cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                @Suppress("DEPRECATION")
                val started = gatt.writeDescriptor(cccd)
                if (!started) {
                    handleConnectionFailure(
                        "notification_enable_failed",
                        "Failed to enable notifications",
                        mapOf("deviceId" to connectedDeviceId)
                    )
                    gatt.disconnect()
                }
            }
        } catch (securityException: SecurityException) {
            Log.e(TAG, "Bluetooth connect permission denied during notification setup", securityException)
            handleConnectionFailure("permission_denied", "Bluetooth connect permission denied")
            gatt.disconnect()
        } catch (exception: Exception) {
            Log.e(TAG, "Failed to enable notifications", exception)
            handleConnectionFailure("unknown_error", "Failed to enable notifications")
            gatt.disconnect()
        }
    }