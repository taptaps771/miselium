# M6 — Local and push notifications

## Implemented foundation

- Notification service contract supports local notification display and push-token registration.
- Safe fallback returns `unsupported` until a platform provider is connected.
- Backend endpoint `POST /v1/devices` registers/updates a device token under the authenticated user and active tenant. Device registrations are unique by `(tenant_id, user_id, device_id)`.
- Device records are tenant-scoped and can be deactivated by a future device-management endpoint.

## Provider integration still required

- Android Firebase Cloud Messaging SDK must obtain the token in the native Android layer and forward it to the authenticated API.
- Android 13+ notification runtime permission must be requested in context.
- Server-side FCM delivery needs Firebase Admin credentials from a secret manager, token invalidation handling, retry policy, and delivery audit. No FCM credential or send operation is included here.
- WebSocket or another foreground channel may be used while the app is active; it is not a replacement for OS push delivery when the app is terminated.
