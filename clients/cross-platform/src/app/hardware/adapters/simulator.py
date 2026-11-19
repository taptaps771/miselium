"""Explicitly opt-in hardware and permission simulators for tests and development."""

from __future__ import annotations

from collections.abc import Iterable, Mapping

from app.hardware.contracts.models import (
    Capability,
    CapabilityInfo,
    HardwareStatus,
    Permission,
    PermissionInfo,
    PermissionStatus,
    Platform,
)


class SimulatedCapabilityAdapter:
    def __init__(
        self,
        platform: Platform,
        states: Mapping[Capability, HardwareStatus],
        *,
        messages: Mapping[Capability, str] | None = None,
    ) -> None:
        self._platform = platform
        self._states = dict(states)
        self._messages = dict(messages or {})

    @property
    def platform(self) -> Platform:
        return self._platform

    @property
    def capabilities(self) -> Iterable[Capability]:
        return tuple(self._states)

    async def probe(self, capability: Capability) -> CapabilityInfo:
        if capability not in self._states:
            return CapabilityInfo(
                capability=capability,
                platform=self.platform,
                status=HardwareStatus.UNSUPPORTED,
                message="Capability tidak disediakan oleh simulator ini.",
            )
        return CapabilityInfo(
            capability=capability,
            platform=self.platform,
            status=self._states[capability],
            message=self._messages.get(capability, "Simulated capability result."),
            details={"simulated": True},
        )


class SimulatedPermissionProvider:
    def __init__(
        self,
        states: Mapping[Permission, PermissionStatus] | None = None,
        request_results: Mapping[Permission, PermissionStatus] | None = None,
    ) -> None:
        self._states = dict(states or {})
        self._request_results = dict(request_results or {})

    async def check(self, permission: Permission) -> PermissionInfo:
        status = self._states.get(permission, PermissionStatus.NOT_DETERMINED)
        return PermissionInfo(
            permission=permission,
            status=status,
            message="Simulated permission state.",
            can_ask_again=status in (PermissionStatus.NOT_DETERMINED, PermissionStatus.DENIED),
        )

    async def request(self, permission: Permission) -> PermissionInfo:
        status = self._request_results.get(
            permission,
            self._states.get(permission, PermissionStatus.NOT_DETERMINED),
        )
        self._states[permission] = status
        return PermissionInfo(
            permission=permission,
            status=status,
            message="Simulated permission request result.",
            can_ask_again=status in (PermissionStatus.NOT_DETERMINED, PermissionStatus.DENIED),
        )
