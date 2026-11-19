from __future__ import annotations

import pytest

from app.hardware.adapters.simulator import SimulatedCapabilityAdapter
from app.hardware.contracts.models import Capability, HardwareStatus, Platform
from app.hardware.registry import CapabilityRegistry


@pytest.mark.asyncio
async def test_registry_starts_with_capabilities_not_checked() -> None:
    registry = CapabilityRegistry(platform=Platform.LINUX)

    assert len(registry.snapshot()) == len(Capability)
    assert all(item.status is HardwareStatus.NOT_CHECKED for item in registry.snapshot())


@pytest.mark.asyncio
async def test_registry_probes_registered_adapter_and_sets_timestamp() -> None:
    registry = CapabilityRegistry(platform=Platform.LINUX)
    adapter = SimulatedCapabilityAdapter(
        Platform.LINUX,
        {Capability.CAMERA: HardwareStatus.AVAILABLE},
        messages={Capability.CAMERA: "Camera simulated as available."},
    )
    registry.register_adapter(adapter)

    result = await registry.probe(Capability.CAMERA)

    assert result.status is HardwareStatus.AVAILABLE
    assert result.checked_at is not None
    assert result.details["simulated"] is True


@pytest.mark.asyncio
async def test_registry_does_not_claim_unregistered_capability_is_unsupported() -> None:
    registry = CapabilityRegistry(platform=Platform.LINUX)

    result = await registry.probe(Capability.NFC)

    assert result.status is HardwareStatus.NOT_CHECKED


def test_registry_rejects_duplicate_capability_adapter() -> None:
    registry = CapabilityRegistry(platform=Platform.LINUX)
    adapter = SimulatedCapabilityAdapter(
        Platform.LINUX,
        {Capability.BLE: HardwareStatus.AVAILABLE},
    )
    registry.register_adapter(adapter)

    with pytest.raises(ValueError, match="already has an adapter"):
        registry.register_adapter(adapter)


def test_registry_rejects_adapter_for_a_different_platform() -> None:
    registry = CapabilityRegistry(platform=Platform.LINUX)
    adapter = SimulatedCapabilityAdapter(
        Platform.ANDROID,
        {Capability.NFC: HardwareStatus.AVAILABLE},
    )

    with pytest.raises(ValueError, match="does not match"):
        registry.register_adapter(adapter)


@pytest.mark.asyncio
async def test_registry_converts_adapter_exception_to_error_status() -> None:
    class BrokenAdapter:
        platform = Platform.LINUX
        capabilities = (Capability.BLUETOOTH,)

        async def probe(self, capability: Capability):
            raise RuntimeError("native driver failure")

    registry = CapabilityRegistry(platform=Platform.LINUX)
    registry.register_adapter(BrokenAdapter())

    result = await registry.probe(Capability.BLUETOOTH)

    assert result.status is HardwareStatus.ERROR
    assert result.details["exception_type"] == "RuntimeError"


@pytest.mark.asyncio
async def test_registry_notifies_listeners_after_probe() -> None:
    registry = CapabilityRegistry(platform=Platform.LINUX)
    adapter = SimulatedCapabilityAdapter(
        Platform.LINUX,
        {Capability.LOCATION: HardwareStatus.UNAVAILABLE},
    )
    registry.register_adapter(adapter)
    seen = []
    registry.subscribe(seen.append)

    await registry.probe(Capability.LOCATION)

    assert len(seen) == 1
    assert seen[0].capability is Capability.LOCATION
