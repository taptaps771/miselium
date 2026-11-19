"""Cross-platform permission orchestration with no implicit permission grants."""

from __future__ import annotations

import logging

from app.hardware.contracts.models import Permission, PermissionInfo, PermissionStatus
from app.hardware.contracts.permissions import PermissionProvider


class UnconfiguredPermissionProvider:
    """Safe default until a real desktop or Android permission adapter is installed."""

    async def check(self, permission: Permission) -> PermissionInfo:
        return PermissionInfo(
            permission=permission,
            status=PermissionStatus.UNKNOWN,
            message="Permission provider belum dikonfigurasi untuk platform ini.",
        )

    async def request(self, permission: Permission) -> PermissionInfo:
        return PermissionInfo(
            permission=permission,
            status=PermissionStatus.UNSUPPORTED,
            message="Permission request belum diimplementasikan untuk platform ini.",
        )


class PermissionManager:
    def __init__(self, provider: PermissionProvider | None = None) -> None:
        self._provider = provider or UnconfiguredPermissionProvider()
        self._logger = logging.getLogger("miselium.hardware.permissions")

    async def check(self, permission: Permission) -> PermissionInfo:
        try:
            info = await self._provider.check(permission)
            self._validate(permission, info)
            return info
        except Exception:
            self._logger.exception("Permission check failed: %s", permission.value)
            return PermissionInfo(
                permission=permission,
                status=PermissionStatus.UNKNOWN,
                message="Permission status could not be determined.",
            )

    async def request(self, permission: Permission) -> PermissionInfo:
        try:
            info = await self._provider.request(permission)
            self._validate(permission, info)
            return info
        except Exception:
            self._logger.exception("Permission request failed: %s", permission.value)
            return PermissionInfo(
                permission=permission,
                status=PermissionStatus.UNKNOWN,
                message="Permission request failed; status remains unknown.",
            )

    @staticmethod
    def _validate(permission: Permission, info: PermissionInfo) -> None:
        if not isinstance(info, PermissionInfo) or info.permission is not permission:
            raise ValueError("permission provider returned information for a different permission")
