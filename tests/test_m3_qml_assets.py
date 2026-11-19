from pathlib import Path

QML_DIR = Path(__file__).resolve().parents[1] / "src" / "app" / "ui"


def test_m3_qml_pages_and_camera_pipeline_are_present() -> None:
    main = (QML_DIR / "Main.qml").read_text(encoding="utf-8")
    dashboard = (QML_DIR / "DashboardPage.qml").read_text(encoding="utf-8")
    camera = (QML_DIR / "CameraPage.qml").read_text(encoding="utf-8")

    assert "DashboardPage" in main and "CameraPage" in main
    assert "HARDWARE ABSTRACTION LAYER" in dashboard
    for qml_type in ("Camera", "CaptureSession", "VideoOutput", "ImageCapture", "CameraPermission"):
        assert qml_type in camera
    assert "appController.cameraImageSaved" in camera
    assert "appController.scanImageFile" in camera
