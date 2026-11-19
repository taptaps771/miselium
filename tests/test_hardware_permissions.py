from __future__ import annotations

import pytest

from app.hardware.adapters.simulator import SimulatedPermissionProvider
from app.hardware.contracts.models import Permission, PermissionStatus
from app.hardware.permission_manager import PermissionManager, UnconfiguredPermissionProvider


@pytest.mark.asyncio
async def test_unconfigured_permission_provider_never_grants_permission() -> None:
    manager = PermissionManager(UnconfiguredPermissionProvider())

    result = await manager.check(Permission.CAMERA)

    assert result.status is PermissionStatus.UNKNOWN


@pytest.mark.asyncio
async def test_simulated_permission_provider_returns_configured_state() -> None:
    provider = SimulatedPermissionProvider(
        states={Permission.LOCATION: PermissionStatus.GRANTED}
    )
    manager = PermissionManager(provider)

    result = await manager.check(Permission.LOCATION)

    assert result.status is PermissionStatus.GRANTED


@pytest.mark.asyncio
async def test_simulated_permission_request_updates_state() -> None:
    provider = SimulatedPermissionProvider(
        request_results={Permission.CAMERA: PermissionStatus.GRANTED}
    )
    manager = PermissionManager(provider)

    result = await manager.request(Permission.CAMERA)
    checked = await manager.check(Permission.CAMERA)

    assert result.status is PermissionStatus.GRANTED
    assert checked.status is PermissionStatus.GRANTED


@pytest.mark.asyncio
async def test_permission_manager_fails_closed_for_wrong_permission_response() -> None:
    class InvalidProvider:
        async def check(self, permission: Permission):
            return type("Info", (), {"permission": Permission.NFC})()

        async def request(self, permission: Permission):
            return await self.check(permission)

    manager = PermissionManager(InvalidProvider())

    result = await manager.check(Permission.CAMERA)

    assert result.status is PermissionStatus.UNKNOWN


@pytest.mark.asyncio
async def test_permission_provider_exception_fails_closed_as_unknown() -> None:
    class BrokenProvider:
        async def check(self, permission: Permission):
            raise RuntimeError("native permission API failed")

        async def request(self, permission: Permission):
            raise RuntimeError("native permission API failed")

    manager = PermissionManager(BrokenProvider())

    result = await manager.check(Permission.CAMERA)

    assert result.status is PermissionStatus.UNKNOWN
