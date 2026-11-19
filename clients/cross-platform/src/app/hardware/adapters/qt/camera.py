"""Qt Multimedia camera capability probe.

The viewfinder and capture controls are composed in QML with Qt Multimedia. This adapter
only probes device availability; it does not request permissions or activate the camera.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any

from app.hardware.contracts.models import (
    Capability,
    CapabilityInfo,
    HardwareStatus,
    Platform,
)


class QtCameraCapabilityAdapter:
    def __init__(
        self,
        platform: Platform,
        *,
        device_provider: Callable[[], list[Any]] | None = None,
    ) -> None:
        self._platform = platform
        self._device_provider = device_provider

    @property
    def platform(self) -> Platform:
        return self._platform

    @property
    def capabilities(self) -> tuple[Capability, ...]:
        return (Capability.CAMERA,)

    async def probe(self, capability: Capability) -> CapabilityInfo:
        if capability is not Capability.CAMERA:
            raise ValueError("QtCameraCapabilityAdapter only supports the camera capability")

        try:
            if self._device_provider is None:
                from PySide6.QtMultimedia import QMediaDevices

                devices = list(QMediaDevices.videoInputs())
            else:
                devices = list(self._device_provider())
        except ImportError:
            status = HardwareStatus.UNSUPPORTED
            message = "PySide6 Qt Multimedia tidak tersedia di lingkungan ini."
            details: dict[str, Any] = {"adapter": "qt-multimedia"}
        except Exception as exc:
            status = HardwareStatus.ERROR
            message = "Daftar perangkat kamera gagal diperiksa."
            details = {"adapter": "qt-multimedia", "exception_type": type(exc).__name__}
        else:
            status = HardwareStatus.AVAILABLE if devices else HardwareStatus.UNAVAILABLE
            message = (
                f"Ditemukan {len(devices)} perangkat kamera."
                if devices
                else "Tidak ditemukan perangkat kamera yang tersedia."
            )
            details = {
                "adapter": "qt-multimedia",
                "device_count": len(devices),
                "devices": [
                    {
                        "description": str(device.description()),
                        "id": str(device.id()),
                    }
                    for device in devices
                ],
            }

        return CapabilityInfo(
            capability=Capability.CAMERA,
            platform=self._platform,
            status=status,
            message=message,
            details=details,
            checked_at=datetime.now(UTC),
        )
