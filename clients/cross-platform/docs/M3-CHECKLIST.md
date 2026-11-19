# M3 Validation Checklist

## Automated

- [x] Camera capability adapter unit tests (available / no device).
- [x] ZXing scanner service tests (payloads, empty scan, invalid input size, decoder failure).
- [x] Scan decoding is dispatched through a Qt worker thread.
- [x] Pytest asyncio fixture loop scope is explicitly set to `function`.

## Linux desktop manual validation

- [ ] `pip install -r requirements/scanner.txt` completes in the Python 3.14 virtual environment.
- [ ] `python scripts/check_hardware.py` reports the camera and scanner states.
- [ ] Dashboard starts without a camera connected.
- [ ] Camera & Scanner tab opens and reports `UNAVAILABLE` when no camera is attached.
- [ ] With a camera attached, preview starts and stops without freezing the dashboard.
- [ ] Captured image is saved below the application-private data directory.
- [ ] A QR image is decoded and its text is displayed.
- [ ] A barcode image is decoded and its symbology is displayed.
- [ ] Selecting an image file works even without a camera.
- [ ] A large/non-image file produces an error message without crashing the app.

## Android manual validation (later packaging pass)

- [ ] Add `android.permission.CAMERA` to the APK/AAB manifest.
- [ ] Verify the runtime permission prompt in a packaged build.
- [ ] Verify deny, grant, and revoke behavior.
- [ ] Verify preview/capture on a physical Android device.
- [ ] Replace the desktop ZXing binding with an Android-architecture-compatible decoder.
