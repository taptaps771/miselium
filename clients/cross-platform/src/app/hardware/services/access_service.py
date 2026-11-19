"""Shared preflight checks for hardware capability and permission readiness."""

from __future__ import annotations

from app.hardware.contracts.models import (
    Capability,
    CapabilityInfo,
    HardwareResult,
    HardwareStatus,
    Permission,
    PermissionStatus,
)
from app.hardware.permission_manager import PermissionManager
from app.hardware.registry import CapabilityRegistry


class HardwareAccessService:
    def __init__(self, registry: CapabilityRegistry, permissions: PermissionManager) -> None:
        self._registry = registry
        self._permissions = permissions

    async def prepare(
        self,
        capability: Capability,
        *,
        permission: Permission | None = None,
        request_permission: bool = False,
    ) -> HardwareResult[CapabilityInfo]:
        """Probe a capability and optionally request its required permission.

        This method does not activate hardware or perform a device operation.
        """
        info = await self._registry.probe(capability)
        if info.status is not HardwareStatus.AVAILABLE:
            return HardwareResult(
                status=info.status,
                data=info,
                message=info.message or f"Capability {capability.value} is not available.",
            )
        if permission is None:
            return HardwareResult(status=HardwareStatus.AVAILABLE, data=info)

        permission_info = await self._permissions.check(permission)
        if permission_info.status is PermissionStatus.NOT_DETERMINED and request_permission:
            permission_info = await self._permissions.request(permission)

        if permission_info.status in (PermissionStatus.GRANTED, PermissionStatus.NOT_REQUIRED):
            return HardwareResult(status=HardwareStatus.AVAILABLE, data=info)
        if permission_info.status in (PermissionStatus.DENIED, PermissionStatus.RESTRICTED):
            status = HardwareStatus.PERMISSION_DENIED
        elif permission_info.status is PermissionStatus.UNSUPPORTED:
            status = HardwareStatus.UNSUPPORTED
        elif permission_info.status is PermissionStatus.NOT_DETERMINED:
            status = HardwareStatus.PERMISSION_REQUIRED
        else:
            status = HardwareStatus.NOT_CHECKED
        return HardwareResult(
            status=status,
            data=info,
            message=permission_info.message,
            code=f"permission_{permission_info.status.value}",
            metadata={"permission": permission.value},
        )
