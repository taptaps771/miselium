from __future__ import annotations

from types import SimpleNamespace

import pytest

from app.hardware.adapters.qt.camera import QtCameraCapabilityAdapter
from app.hardware.contracts.models import Capability, HardwareStatus, Platform


@pytest.mark.asyncio
async def test_camera_probe_reports_available_devices() -> None:
    devices = [SimpleNamespace(description=lambda: "USB Camera", id=lambda: b"camera-1")]
    adapter = QtCameraCapabilityAdapter(Platform.LINUX, device_provider=lambda: devices)

    result = await adapter.probe(Capability.CAMERA)

    assert result.status is HardwareStatus.AVAILABLE
    assert result.details["device_count"] == 1
    assert result.details["devices"][0]["description"] == "USB Camera"


@pytest.mark.asyncio
async def test_camera_probe_reports_unavailable_when_no_camera_is_found() -> None:
    adapter = QtCameraCapabilityAdapter(Platform.LINUX, device_provider=list)

    result = await adapter.probe(Capability.CAMERA)

    assert result.status is HardwareStatus.UNAVAILABLE
    assert result.details["device_count"] == 0
