# M8 Validation Checklist

- [x] Linux/Windows CI test matrix defined for Python 3.14.
- [x] Ruff, pytest, and compile checks in CI.
- [x] Desktop PyInstaller package workflow defined for Linux and Windows.
- [x] Android manifest template and permission validation script.
- [x] Manual Android toolchain-readiness workflow.
- [ ] CI workflows executed successfully on the target GitHub repository.
- [ ] Linux desktop artifact installed and smoke-tested on a clean machine.
- [ ] Windows desktop artifact installed and smoke-tested on a clean machine.
- [ ] Android arm64-v8a APK/AAB built and installed.
- [ ] Native bridges and permission flows tested on physical Android hardware.
- [ ] Release signing, dependency scan, security review, backup/restore, and rollback tested.
