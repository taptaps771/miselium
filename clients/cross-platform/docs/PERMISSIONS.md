# Permission model — M0–M8

## Principles

- Never assume a permission is granted because a Python or Qt module imports successfully.
- Never request permissions on application startup without a feature-specific user action and explanation.
- Check first; request only when the user starts a feature that needs the permission.
- Treat `denied`, `restricted`, `not_determined`, `unsupported`, and `unknown` as distinct states.
- Do not silently retry a permission request after a permanent denial. Guide the user to OS settings where supported.
- Background location and background Bluetooth are separate capabilities from foreground access. They require explicit platform-specific services and policies.
- Biometric data must remain inside the operating system's biometric subsystem. The application receives only an authentication outcome, not fingerprint/face templates.

## Permission states

| State | Application behavior |
|---|---|
| `granted` | The requested operation may proceed, subject to capability availability. |
| `not_required` | The platform does not require a runtime permission for this operation. |
| `not_determined` | Ask only after an explanatory user action. |
| `denied` | Do not access the feature; explain how to retry or open settings if possible. |
| `restricted` | Access is blocked by OS/device policy. |
| `unsupported` | The platform adapter cannot request/check this permission. |
| `unknown` | No permission provider is configured or the state could not be established. Do not treat as granted. |

## Implementation status

M2 provides the permission contract, manager, safe unconfigured provider, and a test-only simulator. M3 adds a user-triggered Qt QML `CameraPermission` request on Android. M4 declares location/Bluetooth permissions but does not yet ship a tested native provider. M5 defines the Android bridge boundary for NFC, AndroidX BiometricPrompt, Storage Access Framework, and share intents; the Java/Kotlin bridge and runtime permission UX remain pending. M6 declares the notification permission in the Android manifest template; FCM token acquisition and notification prompts remain pending. The general HAL `PermissionManager` still needs to be connected to each native permission provider and physical-device test.
