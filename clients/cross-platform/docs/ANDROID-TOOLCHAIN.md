# Miselium Android toolchain notes

Do not install Android SDK/NDK just to run the desktop M0 prototype.

For the currently documented Qt for Python Android deployment flow:

- Build host: Linux or macOS (not Windows directly).
- Host Python: 3.10 through 3.14.
- JDK: 17 or later.
- Android NDK: r28c, version `28.2.13676358`.
- Android SDK packages documented by Qt: `platform-tools`, `platforms;android-35`,
  and `build-tools;35.0.0`.
- Android architectures documented by the tool: `arm64-v8a` and `x86_64`.
- Main application entry point must be named `main.py`.

Qt's tool can download its expected SDK/NDK set with the helper in the Qt for Python
repository. Follow the live official documentation before installing because this toolchain
is version-coupled:

https://doc.qt.io/qtforpython-6/deployment/deployment-pyside6-android-deploy.html

The Android Python runtime is built separately by python-for-android. Do not assume that
the host virtual environment or its desktop wheels are copied directly into the APK.


## M3 camera permission

The M3 camera page uses Qt Multimedia QML (`Camera`, `CaptureSession`, `VideoOutput`, and
`ImageCapture`) and Qt QML Core's `CameraPermission`. The Android package must declare
`android.permission.CAMERA` in its deployment manifest. The permission prompt is expected to be
validated from a packaged Android app; Qt for Python documents that the Qt Permission API is not
functional when the application is run as an interpreted Python script.

The current camera capture path uses the application-private data directory. This avoids assuming
that Android shared-storage paths are directly writable.


## M8 packaging status

`platforms/android/AndroidManifest.xml` is a permission/feature template and `scripts/check_android_manifest.py` validates required declarations. It is not yet a generated, signed APK manifest. The manual workflow only checks that the PySide6 Android deploy command is present and its help can be displayed. Build and release must follow the version-matched official Qt for Python deployment guide; native bridges and physical-device validation are separate release gates.
