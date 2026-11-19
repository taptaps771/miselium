# M6 Validation Checklist

- [x] Local/push notification service contract exists.
- [x] Missing notification provider returns `unsupported`.
- [x] Authenticated device registration is tenant-scoped and idempotently updates a device.
- [ ] Android FCM SDK bridge obtains and refreshes tokens.
- [ ] Notification runtime permission flow tested on Android 13+.
- [ ] Firebase Admin delivery, invalid-token cleanup, retry, and delivery audit implemented.
- [ ] Push notification tested with app foregrounded, backgrounded, and terminated.
