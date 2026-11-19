# M8 — QA, packaging, and release hardening

## Automated checks in the repository

- CI matrix: Python 3.14 on Ubuntu and Windows.
- Ruff lint, pytest, and bytecode compilation.
- Desktop packaging job builds PyInstaller distributions on Ubuntu and Windows and uploads artifacts.
- A manual Android toolchain workflow checks the PySide6 Android deploy CLI and validates the manifest. It does not claim to produce a signed APK/AAB.

## Desktop package

```bash
python -m pip install -r requirements/package.txt
python scripts/package_desktop.py --clean
```

Artifacts are written to `dist/`. Run the packaged application on a clean machine to validate Qt plugins, QML imports, multimedia backends, camera permissions, and native dependencies. Linux and Windows packaging jobs must both pass before publishing a desktop release.

## Android build

The Android manifest template is in `platforms/android/AndroidManifest.xml`. Use the PySide6 6.12.0 Android deployment tool with the exact supported SDK/NDK versions, target architecture, deployment configuration, and required Python wheels. The optional desktop ZXing binding must not be bundled as an Android wheel unless an Android ABI-compatible build exists.

Android packaging is not marked complete until all of the following are available:

- A reproducible arm64-v8a build on a supported Linux build host.
- Camera, location, BLE, NFC, notification, and biometric native bridge implementations included in the package as appropriate.
- Runtime permission grant/deny/revoke tests on a physical Android device.
- Signed release AAB/APK using credentials held only in GitHub Actions secrets or a secure release system.
- Install/upgrade/uninstall smoke tests and a documented rollback process.

## Release checklist

- [ ] Linux desktop artifact installed and smoke-tested on a clean machine.
- [ ] Windows desktop artifact installed and smoke-tested on a clean machine.
- [ ] Android arm64-v8a APK/AAB built reproducibly.
- [ ] Android physical-device hardware and permission checks completed.
- [ ] Backend PostgreSQL migration, backup, restore, TLS, rate limiting, and monitoring verified.
- [ ] Email, push provider, billing, refresh-token lifecycle, and privacy/retention policies configured.
- [ ] Security review and dependency vulnerability scan completed.

The current source implements the release pipeline and validation scaffolding; Android release packaging, signing, provider credentials, and physical-device tests remain external release gates.
