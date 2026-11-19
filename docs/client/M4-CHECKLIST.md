# M4 Validation Checklist

- [x] Location and BLE contracts exist in the HAL.
- [x] Qt Positioning and Qt Bluetooth capability probes are registered.
- [x] Module import does not claim a physical device is available.
- [x] Missing service implementations return typed `unsupported` results.
- [ ] Real GPS fix and accuracy verified on Linux/Windows hardware.
- [ ] BLE scan/connect/cancel tested on desktop hardware.
- [ ] Android runtime permission flows and BLE/GPS tested on physical device.
- [ ] Android background location foreground-service lifecycle implemented and tested.
