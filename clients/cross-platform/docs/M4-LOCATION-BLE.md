# M4 — Location and Bluetooth Low Energy

## Implemented in this milestone

- Location and BLE capability declarations use the existing platform-neutral HAL.
- Qt Positioning and Qt Bluetooth module probes are registered at runtime.
- A module import is reported as `not_checked`, never `available`: it does not prove a GPS fix, BLE radio, permission grant, or attached device.
- Typed location/Bluetooth service contracts and safe `unsupported` fallback services are present.
- Background location is intentionally not implemented as a Python timer. Android background tracking needs a foreground service, notification, manifest declarations, and runtime permission flow.

## Native implementation boundary

The actual `QGeoPositionInfoSource` and `QBluetoothDeviceDiscoveryAgent` operations must be driven from the Qt event loop and connected to the app's asynchronous orchestration. The current project has not yet shipped a tested Qt/Android event-loop bridge. A future native adapter must:

1. Check/request foreground location and Bluetooth scan/connect permissions separately.
2. Report location accuracy and capture timestamp; reject invalid coordinates.
3. Stop BLE discovery on timeout, cancellation, app shutdown, and permission revocation.
4. Avoid exposing stable hardware identifiers unless the feature requires them.
5. Implement background tracking only with the platform's approved service lifecycle.

## Manual validation still required

- Linux/Windows desktop: location source and BLE adapter behavior with real hardware.
- Android: GPS, BLE scan/connect, permission denial/revocation, and background-service lifecycle on physical devices.
