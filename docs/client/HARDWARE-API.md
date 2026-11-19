# Hardware API — M2

## Boundary rules

1. QML communicates with the application layer only. It must not import or call hardware APIs.
2. `app.hardware.contracts` contains Python-only contracts and immutable value objects. It must not import PySide6, Android SDK classes, or platform-specific libraries.
3. Platform adapters implement `CapabilityAdapter` and `PermissionProvider`. A platform-specific bridge is responsible for translating native callbacks into these contracts.
4. Feature services exposed to use cases are asynchronous. Long-running scans, camera capture, and device connections must never block the Qt UI thread.
5. A URI is used for selected/shared files. Android `content://` URIs must not be forced into ordinary filesystem paths.
6. The simulator is for tests and development only. It is never registered by the production bootstrap.

## Capability inventory

The registry currently declares: `camera`, `barcode_scanner`, `location`, `location_background`, `bluetooth`, `ble`, `nfc`, `biometric`, `push_notifications`, `file_access`, and `file_sharing`.

| Status | Meaning |
|---|---|
| `available` | An installed adapter probed the capability and reports it ready. |
| `unavailable` | The capability exists on this platform, but the device/service is not currently available. |
| `unsupported` | The adapter confirms that this platform/device cannot provide the capability. |
| `permission_required` | A required permission has not yet been granted or requested. |
| `permission_denied` | The OS/user denied the required permission or restricted it. |
| `busy` | The hardware resource is currently in use. |
| `error` | The probe or adapter operation failed. |
| `not_checked` | No adapter has probed this capability yet. This is not the same as unsupported. |

## Probe flow

```text
Application use case
       │
       ▼
HardwareAccessService.prepare(capability, permission)
       │
       ├── CapabilityRegistry.probe(capability)
       │       └── Platform CapabilityAdapter
       │
       └── PermissionManager.check/request(permission)
               └── Platform PermissionProvider
       │
       ▼
HardwareResult[CapabilityInfo]
```

`prepare()` is a preflight check only. It does not open the camera, start location tracking, connect BLE, read NFC, or perform any other physical operation. Feature operations are implemented in later milestones behind the protocols in `contracts/services.py`.

## Registering an adapter

```python
registry.register_adapter(android_adapter)
info = await registry.probe(Capability.NFC)
```

An adapter declares its platform and the capabilities it owns. The registry rejects an adapter for the wrong platform and rejects duplicate ownership. Unexpected probe exceptions become an `error` result and are logged rather than crashing the application.

## Result handling

Hardware operations return `HardwareResult[T]`. Callers should check `result.status` or `result.is_success`; do not assume that a `None` payload means success. User-facing messages should be localized at the application/UI boundary.
