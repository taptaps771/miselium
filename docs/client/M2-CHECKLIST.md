# M2 checklist — Hardware Abstraction Layer foundation

- [x] Platform-neutral hardware models and statuses.
- [x] Capability inventory for camera, scanner, location, Bluetooth/BLE, NFC, biometrics, notifications, files, and sharing.
- [x] Capability adapter protocol and registry.
- [x] Safe `not_checked` initial state; no implicit hardware claims.
- [x] Permission provider contract, manager, and safe unconfigured default.
- [x] Shared hardware access preflight service.
- [x] Explicit capability and permission simulators for tests/development.
- [x] Asynchronous feature-level service protocols.
- [x] QML dashboard view of the capability inventory through the application controller.
- [x] Tests for registry, permissions, preflight status handling, and value validation.
- [ ] Native Linux/Windows/Android device adapters (later milestones).
- [ ] Real device hardware validation (later milestones).
- [ ] Android background service and native permission bridge (later milestones).

## Validation

```bash
pytest -q
ruff check .
python scripts/check_environment.py
python main.py
```

A successful M2 test run validates the contracts and orchestration logic only. It does not prove that a physical camera, GPS receiver, BLE adapter, NFC reader, biometric sensor, push service, or file provider is accessible.
