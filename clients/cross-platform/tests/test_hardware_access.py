from __future__ import annotations

import pytest

from app.hardware.adapters.simulator import (
    SimulatedCapabilityAdapter,
    SimulatedPermissionProvider,
)
from app.hardware.contracts.models import (
    Capability,
    HardwareStatus,
    Permission,
    PermissionStatus,
    Platform,
)
from app.hardware.permission_manager import PermissionManager
from app.hardware.registry import CapabilityRegistry
from app.hardware.services.access_service import HardwareAccessService


@pytest.mark.asyncio
async def test_access_service_returns_not_checked_without_platform_adapter() -> None:
    registry = CapabilityRegistry(platform=Platform.LINUX)
    service = HardwareAccessService(registry, PermissionManager())

    result = await service.prepare(Capability.CAMERA)

    assert result.status is HardwareStatus.NOT_CHECKED


@pytest.mark.asyncio
async def test_access_service_returns_available_when_permission_is_granted() -> None:
    registry = CapabilityRegistry(platform=Platform.LINUX)
    registry.register_adapter(
        SimulatedCapabilityAdapter(
            Platform.LINUX,
            {Capability.CAMERA: HardwareStatus.AVAILABLE},
        )
    )
    permissions = PermissionManager(
        SimulatedPermissionProvider(states={Permission.CAMERA: PermissionStatus.GRANTED})
    )
    service = HardwareAccessService(registry, permissions)

    result = await service.prepare(Capability.CAMERA, permission=Permission.CAMERA)

    assert result.status is HardwareStatus.AVAILABLE
    assert result.is_success is True


@pytest.mark.asyncio
async def test_access_service_can_request_not_yet_determined_permission() -> None:
    registry = CapabilityRegistry(platform=Platform.ANDROID)
    registry.register_adapter(
        SimulatedCapabilityAdapter(
            Platform.ANDROID,
            {Capability.LOCATION: HardwareStatus.AVAILABLE},
        )
    )
    permissions = PermissionManager(
        SimulatedPermissionProvider(
            request_results={Permission.LOCATION: PermissionStatus.GRANTED}
        )
    )
    service = HardwareAccessService(registry, permissions)

    result = await service.prepare(
        Capability.LOCATION,
        permission=Permission.LOCATION,
        request_permission=True,
    )

    assert result.status is HardwareStatus.AVAILABLE


@pytest.mark.asyncio
async def test_access_service_reports_permission_required_without_prompting() -> None:
    registry = CapabilityRegistry(platform=Platform.ANDROID)
    registry.register_adapter(
        SimulatedCapabilityAdapter(
            Platform.ANDROID,
            {Capability.CAMERA: HardwareStatus.AVAILABLE},
        )
    )
    service = HardwareAccessService(
        registry,
        PermissionManager(SimulatedPermissionProvider()),
    )

    result = await service.prepare(Capability.CAMERA, permission=Permission.CAMERA)

    assert result.status is HardwareStatus.PERMISSION_REQUIRED


@pytest.mark.asyncio
async def test_access_service_denied_permission_blocks_access() -> None:
    registry = CapabilityRegistry(platform=Platform.ANDROID)
    registry.register_adapter(
        SimulatedCapabilityAdapter(
            Platform.ANDROID,
            {Capability.CAMERA: HardwareStatus.AVAILABLE},
        )
    )
    service = HardwareAccessService(
        registry,
        PermissionManager(
            SimulatedPermissionProvider(states={Permission.CAMERA: PermissionStatus.DENIED})
        ),
    )

    result = await service.prepare(Capability.CAMERA, permission=Permission.CAMERA)

    assert result.status is HardwareStatus.PERMISSION_DENIED
    assert result.metadata["permission"] == Permission.CAMERA.value
