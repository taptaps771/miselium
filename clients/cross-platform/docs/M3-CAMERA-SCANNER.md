# M3 — Camera and QR / Barcode Scanner

## Scope

M3 adds the first real device-facing feature while keeping platform access behind Qt's cross-platform
Multimedia layer. The camera page is implemented in QML with `Camera`, `MediaDevices`,
`CaptureSession`, `VideoOutput`, and `ImageCapture`. Python remains the application coordinator: it
prepares an app-private capture path, receives the saved image event, and dispatches decoding to a
worker thread.

QR and barcode decoding uses the optional ZXing-C++ Python binding. The binding is intentionally
separate from the base desktop requirements because native wheel availability differs by target.
The current desktop implementation reads image bytes with Pillow, converts them to a NumPy RGB
array, and passes that array to ZXing-C++. It supports QR Code and the formats provided by the
installed ZXing-C++ build.

## Install

```bash
pip install -r requirements/scanner.txt
python scripts/check_hardware.py
python main.py
```

If the scanner dependency is absent, the app still starts and the UI reports `UNSUPPORTED` for the
barcode scanner. The camera page also has a **Pilih gambar** action, so a scanner test does not
require a working webcam.

## Camera flow

1. User opens the Camera & Scanner tab.
2. User starts the camera; Android requests camera permission through `CameraPermission`.
3. Qt Multimedia displays the preview through `VideoOutput`.
4. User captures a still image. `ImageCapture` saves it to the app-private capture directory.
5. The saved-file signal is passed to the Python controller.
6. The controller reads the image and starts a `QRunnable` in `QThreadPool`.
7. ZXing-C++ returns zero or more `ScanPayload` values; the UI receives the result through a Qt signal.

A selected local image uses the same decoding pipeline as a captured image. Image input is limited
to 20 MiB. Decoding never runs in the GUI thread.

## Capability status

- Camera: `AVAILABLE` when Qt reports one or more video input devices; otherwise `UNAVAILABLE`.
- Barcode scanner: `AVAILABLE` when `zxingcpp`, `numpy`, and `Pillow` are importable; otherwise
  `UNSUPPORTED`.
- Permission: Android camera permission is requested by the QML permission object. The general HAL
  permission provider remains separate and is not yet wired to Android native permission results.

## Android notes

The Android package needs `android.permission.CAMERA`. Permission API behavior must be tested from
a packaged Android build, not by running `python main.py`; see `ANDROID-TOOLCHAIN.md`. The current
ZXing Python wheel integration is for desktop. Android decoding will need an Android-compatible
native ZXing build or a thin Java/C++ bridge, which is deliberately left for Android packaging work.

## Known boundaries

- No continuous real-time frame decoding yet; scanning happens on captured or selected still images.
- No flash/torch, focus, zoom, or camera selection controls yet.
- No OCR, face detection, or video recording.
- Physical behavior must be verified on a computer with a camera and later on Android hardware.
