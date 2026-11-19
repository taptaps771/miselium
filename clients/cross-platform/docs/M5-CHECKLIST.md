# M5 Validation Checklist

- [x] NFC, biometric, file picker, and file sharing contracts are defined.
- [x] Android native bridge protocol and fail-closed fallback adapters are present.
- [x] Capability registry reports native bridge absence as `unsupported`.
- [ ] Java/Kotlin or C++/JNI Android bridge packaged.
- [ ] NFC NDEF reader mode tested on physical NFC device.
- [ ] AndroidX BiometricPrompt tested on enrolled and unenrolled devices.
- [ ] Storage Access Framework content URI permissions tested.
- [ ] Share intent tested with multiple receiving apps.
