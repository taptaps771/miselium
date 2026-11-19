"""Qt-facing application information and UI actions."""

from __future__ import annotations

import asyncio
import json
import logging
import platform
from datetime import datetime
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path

from PySide6.QtCore import (
    QCoreApplication,
    QGuiApplication,
    QObject,
    Property,
    QRunnable,
    QStandardPaths,
    QThreadPool,
    QUrl,
    Signal,
    Slot,
)

from app.config import AppSettings
from app.core.lifecycle import AppLifecycle
from app.hardware.adapters.zxing.barcode_scanner import ZXingBarcodeScanner
from app.hardware.contracts.models import (
    Capability,
    HardwareResult,
    HardwareStatus,
    ScanPayload,
)
from app.hardware.runtime import HardwareRuntime, create_hardware_runtime


class _ScanSignals(QObject):
    finished = Signal(object, object)


class _ScanTask(QRunnable):
    """Run image decoding away from the GUI thread."""

    def __init__(self, scanner: ZXingBarcodeScanner, image_bytes: bytes) -> None:
        super().__init__()
        self.setAutoDelete(False)
        self.scanner = scanner
        self.image_bytes = image_bytes
        self.signals = _ScanSignals()

    @Slot()
    def run(self) -> None:
        try:
            result = asyncio.run(self.scanner.scan_image(self.image_bytes))
        except Exception as exc:  # The worker must always return a typed result.
            result = HardwareResult(
                status=HardwareStatus.ERROR,
                message="Pemindaian gambar gagal diproses.",
                code="scan_worker_error",
                metadata={"exception_type": type(exc).__name__},
            )
        self.signals.finished.emit(result, self)


class AppController(QObject):
    """Expose a small, stable application API to QML."""

    lifecycleStateChanged = Signal()  # noqa: N815 - Qt/QML signal naming
    cameraStateChanged = Signal()  # noqa: N815 - Qt/QML signal naming
    scanStateChanged = Signal()  # noqa: N815 - Qt/QML signal naming

    def __init__(
        self,
        settings: AppSettings,
        lifecycle: AppLifecycle,
        log_file: Path,
        parent: QObject | None = None,
        *,
        hardware_runtime: HardwareRuntime | None = None,
    ) -> None:
        super().__init__(parent)
        self._settings = settings
        self._lifecycle = lifecycle
        self._log_file = str(log_file)
        self._hardware_runtime = hardware_runtime or create_hardware_runtime()
        self._barcode_scanner = ZXingBarcodeScanner()
        self._thread_pool = QThreadPool.globalInstance()
        self._scan_jobs: list[_ScanTask] = []
        self._scan_busy = False
        self._scan_message = "Belum ada gambar yang dipindai."
        self._scan_results_json = "[]"
        self._last_camera_error = ""
        self._logger = logging.getLogger("miselium.camera")
        lifecycle.subscribe(lambda _state: self.lifecycleStateChanged.emit())
        try:
            self._pyside_version = version("PySide6")
        except PackageNotFoundError:
            self._pyside_version = "unknown"

    @Property(str, constant=True)
    def appName(self) -> str:  # noqa: N802 - Qt property naming
        return self._settings.app_name

    @Property(str, constant=True)
    def appVersion(self) -> str:  # noqa: N802 - Qt property naming
        return self._settings.app_version

    @Property(str, constant=True)
    def environment(self) -> str:
        return self._settings.environment

    @Property(str, constant=True)
    def pythonVersion(self) -> str:  # noqa: N802 - Qt property naming
        return platform.python_version()

    @Property(str, constant=True)
    def pysideVersion(self) -> str:  # noqa: N802 - Qt property naming
        return self._pyside_version

    @Property(str, constant=True)
    def platformName(self) -> str:  # noqa: N802 - Qt property naming
        return platform.system() or "Unknown"

    @Property(str, notify=lifecycleStateChanged)
    def lifecycleState(self) -> str:  # noqa: N802 - Qt property naming
        return self._lifecycle.state.value

    @Property(str, constant=True)
    def logFile(self) -> str:  # noqa: N802 - Qt property naming
        return self._log_file

    @Property(str, constant=True)
    def apiBaseUrl(self) -> str:  # noqa: N802 - Qt property naming
        return str(self._settings.api_base_url or "Not configured")

    @Property(str, constant=True)
    def hardwarePlatform(self) -> str:  # noqa: N802 - Qt property naming
        return self._hardware_runtime.registry.platform.value

    @Property(int, constant=True)
    def hardwareCapabilityCount(self) -> int:  # noqa: N802 - Qt property naming
        return len(self._hardware_runtime.registry.snapshot())

    @Property(str, constant=True)
    def hardwareCapabilitiesJson(self) -> str:  # noqa: N802 - Qt property naming
        labels = {
            "camera": "Camera",
            "barcode_scanner": "QR / Barcode Scanner",
            "location": "GPS / Location",
            "location_background": "Background Location",
            "bluetooth": "Bluetooth",
            "ble": "Bluetooth Low Energy",
            "nfc": "NFC",
            "biometric": "Biometric Authentication",
            "push_notifications": "Push Notifications",
            "file_access": "File Access",
            "file_sharing": "File Sharing",
        }
        rows = [
            {
                "id": info.capability.value,
                "label": labels.get(info.capability.value, info.capability.value),
                "status": info.status.value,
                "message": info.message,
            }
            for info in self._hardware_runtime.registry.snapshot()
        ]
        return json.dumps(rows, ensure_ascii=False)

    @Property(bool, notify=cameraStateChanged)
    def cameraAvailable(self) -> bool:  # noqa: N802 - Qt property naming
        info = self._hardware_runtime.registry.get(Capability.CAMERA)
        return info.status is HardwareStatus.AVAILABLE

    @Property(str, notify=cameraStateChanged)
    def cameraStatus(self) -> str:  # noqa: N802 - Qt property naming
        info = self._hardware_runtime.registry.get(Capability.CAMERA)
        return self._last_camera_error or info.message or info.status.value

    @Property(bool, notify=scanStateChanged)
    def scannerAvailable(self) -> bool:  # noqa: N802 - Qt property naming
        info = self._hardware_runtime.registry.get(Capability.BARCODE_SCANNER)
        return info.status is HardwareStatus.AVAILABLE

    @Property(bool, notify=scanStateChanged)
    def scanBusy(self) -> bool:  # noqa: N802 - Qt property naming
        return self._scan_busy

    @Property(str, notify=scanStateChanged)
    def scanMessage(self) -> str:  # noqa: N802 - Qt property naming
        return self._scan_message

    @Property(str, notify=scanStateChanged)
    def scanResultsJson(self) -> str:  # noqa: N802 - Qt property naming
        return self._scan_results_json

    @Slot(result=str)
    def createCameraCapturePath(self) -> str:  # noqa: N802 - Qt slot naming
        """Return an app-private capture path that is writable on desktop and Android."""
        root = QStandardPaths.writableLocation(
            QStandardPaths.StandardLocation.AppLocalDataLocation
        )
        capture_dir = (
            Path(root) / "captures"
            if root
            else Path.home() / ".miselium" / "captures"
        )
        capture_dir.mkdir(parents=True, exist_ok=True)
        filename = f"capture-{datetime.now().strftime('%Y%m%d-%H%M%S-%f')}.jpg"
        return str(capture_dir / filename)

    @Slot(str)
    def cameraImageSaved(self, file_name: str) -> None:  # noqa: N802 - Qt slot naming
        """Automatically scan a photo saved by the QML ImageCapture component."""
        self.scanImageFile(file_name)

    @Slot(str)
    def reportCameraError(self, message: str) -> None:  # noqa: N802 - Qt slot naming
        self._last_camera_error = message or "Kamera melaporkan kesalahan yang tidak diketahui."
        self._logger.warning("Camera error: %s", self._last_camera_error)
        self.cameraStateChanged.emit()

    @Slot(str)
    def scanImageFile(self, file_uri_or_path: str) -> None:  # noqa: N802 - Qt slot naming
        """Read a local image and dispatch decoding to a worker thread."""
        if self._scan_busy:
            self._scan_message = "Pemindaian sebelumnya masih berlangsung."
            self.scanStateChanged.emit()
            return

        candidate = QUrl(file_uri_or_path)
        local_path = candidate.toLocalFile() if candidate.isLocalFile() else file_uri_or_path
        path = Path(local_path).expanduser()
        try:
            if not path.is_file():
                raise FileNotFoundError("File gambar tidak ditemukan.")
            if path.stat().st_size > 20 * 1024 * 1024:
                raise OSError("Ukuran gambar melebihi batas 20 MB.")
            image_bytes = path.read_bytes()
        except OSError as exc:
            self._scan_message = f"Gambar tidak dapat dibaca: {exc}"
            self._scan_results_json = "[]"
            self.scanStateChanged.emit()
            return

        self._dispatch_scan(image_bytes)

    def _dispatch_scan(self, image_bytes: bytes) -> None:
        self._scan_busy = True
        self._scan_message = "Sedang membaca QR code / barcode…"
        self._scan_results_json = "[]"
        task = _ScanTask(self._barcode_scanner, image_bytes)
        self._scan_jobs.append(task)
        task.signals.finished.connect(self._on_scan_finished)
        self.scanStateChanged.emit()
        self._thread_pool.start(task)

    @Slot(object, object)
    def _on_scan_finished(self, result: HardwareResult, task: _ScanTask) -> None:
        if task in self._scan_jobs:
            self._scan_jobs.remove(task)
        self._scan_busy = False
        self._scan_message = result.message or result.status.value
        payloads = result.data if isinstance(result.data, tuple) else ()
        self._scan_results_json = json.dumps(
            [
                {"value": payload.value, "format": payload.format}
                for payload in payloads
                if isinstance(payload, ScanPayload)
            ],
            ensure_ascii=False,
        )
        self._logger.info(
            "Image scan completed with status=%s code=%s", result.status.value, result.code
        )
        self.scanStateChanged.emit()

    @Slot(str)
    def copyText(self, value: str) -> None:  # noqa: N802 - Qt slot naming
        QGuiApplication.clipboard().setText(value)

    @Slot()
    def shutdown(self) -> None:
        """Give any active image decode a bounded chance to finish before exit."""
        self._thread_pool.waitForDone(3000)

    @Slot()
    def quit(self) -> None:
        self._lifecycle.begin_shutdown()
        self.shutdown()
        QCoreApplication.quit()
