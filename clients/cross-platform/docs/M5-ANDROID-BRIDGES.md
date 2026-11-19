# M5 — Android native feature bridges

## Shared contracts and safe fallback

The Python HAL contains typed NFC, biometric, file picker, and file sharing contracts. Desktop builds without a platform adapter return `unsupported`; they do not pretend an operation succeeded.

`AndroidNativeBridge` defines the boundary expected from a packaged Java/Kotlin or C++/JNI extension. Qt's `QJniObject` is a C++ API; this project does not assume it can be invoked directly from Python. The bridge implementation and its APK integration remain a platform build task.

## Required Android implementation

- **NFC:** Android `NfcAdapter` reader mode, tag discovery, NDEF parsing, lifecycle pause/resume, NFC hardware feature detection, and runtime/manifest checks. Do not treat tag UID as a universal stable identity.
- **Biometrics:** AndroidX `BiometricPrompt` with a `BiometricManager` capability check. The application receives only an authentication result; it must never read, store, or transmit fingerprint/face templates.
- **File access:** Android Storage Access Framework (`ACTION_OPEN_DOCUMENT` / content URI). Keep URI permissions when persisted access is needed. Do not assume content URIs are filesystem paths.
- **Sharing:** Android share intent (`ACTION_SEND`) with MIME type and URI grants. Share content URIs, not raw private paths.

## Current state

- Python contracts, typed data models, bridge protocol, capability registration, and unsupported fallbacks: implemented and unit-tested.
- Android Java/Kotlin bridge, APK integration, permission UX, and physical-device verification: pending; no Android build is claimed by this milestone.
