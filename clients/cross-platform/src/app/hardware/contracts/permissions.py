"""Permission provider contract; platform implementations live in adapters."""

from __future__ import annotations

from typing import Protocol

from app.hardware.contracts.models import Permission, PermissionInfo


class PermissionProvider(Protocol):
    async def check(self, permission: Permission) -> PermissionInfo: ...

    async def request(self, permission: Permission) -> PermissionInfo: ...
