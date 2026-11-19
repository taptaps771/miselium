from __future__ import annotations

import pytest

from app.hardware.adapters.platform.capabilities import (
    NativeBridgeCapabilityAdapter,
    QtModuleCapabilityAdapter,
)
from app.hardware.adapters.platform.unavailable import (
    UnsupportedBiometricService,
    UnsupportedBluetoothService,
    UnsupportedFileService,
    UnsupportedLocationService,
    UnsupportedNfcService,
    UnsupportedNotificationService,
)
from app.hardware.contracts.models import Capability, HardwareStatus, Platform


@pytest.mark.asyncio
async def test_missing_native_features_fail_closed() -> None:
    services = [
        await UnsupportedLocationService().current_position(),
        await UnsupportedBluetoothService().scan(),
        await UnsupportedNfcService().read_tag(),
        await UnsupportedBiometricService().authenticate("Confirm identity"),
        await UnsupportedFileService().pick_file(),
        await UnsupportedNotificationService().register_push_token(),
    ]
    assert all(result.status is HardwareStatus.UNSUPPORTED for result in services)


@pytest.mark.asyncio
async def test_native_bridge_capability_does_not_claim_hardware_is_present() -> None:
    adapter = NativeBridgeCapabilityAdapter(Platform.ANDROID, Capability.NFC, bridge_available=True)
    result = await adapter.probe(Capability.NFC)
    assert result.status is HardwareStatus.NOT_CHECKED
    assert result.details["native_bridge_available"] is True


@pytest.mark.asyncio
async def test_qt_module_import_is_not_mistaken_for_a_physical_device() -> None:
    adapter = QtModuleCapabilityAdapter(Platform.LINUX, Capability.LOCATION, "json")
    result = await adapter.probe(Capability.LOCATION)
    assert result.status is HardwareStatus.NOT_CHECKED
    assert result.details["physical_device_verified"] is False
