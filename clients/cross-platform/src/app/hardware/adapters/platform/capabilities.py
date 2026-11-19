"""Capability probes for Qt modules and explicit native bridge availability."""

from __future__ import annotations

from datetime import UTC, datetime

from app.hardware.contracts.models import Capability, CapabilityInfo, HardwareStatus, Platform


class QtModuleCapabilityAdapter:
    def __init__(self, platform: Platform, capability: Capability, module: str) -> None:
        self._platform = platform
        self._capability = capability
        self._module = module

    @property
    def platform(self) -> Platform:
        return self._platform

    @property
    def capabilities(self) -> tuple[Capability, ...]:
        return (self._capability,)

    async def probe(self, capability: Capability) -> CapabilityInfo:
        if capability is not self._capability:
            raise ValueError("adapter queried for an unrelated capability")
        try:
            __import__(self._module)
        except ImportError:
            status = HardwareStatus.UNSUPPORTED
            message = f"Modul {self._module} tidak tersedia."
        else:
            # A module import is not proof that a physical device exists or is permitted.
            status = HardwareStatus.NOT_CHECKED
            message = "Modul Qt tersedia; perangkat fisik dan izin belum diverifikasi."
        return CapabilityInfo(
            capability=capability,
            platform=self._platform,
            status=status,
            message=message,
            details={"module": self._module, "physical_device_verified": False},
            checked_at=datetime.now(UTC),
        )


class NativeBridgeCapabilityAdapter:
    def __init__(
        self,
        platform: Platform,
        capability: Capability,
        bridge_available: bool = False,
    ) -> None:
        self._platform = platform
        self._capability = capability
        self._bridge_available = bridge_available

    @property
    def platform(self) -> Platform:
        return self._platform

    @property
    def capabilities(self) -> tuple[Capability, ...]:
        return (self._capability,)

    async def probe(self, capability: Capability) -> CapabilityInfo:
        if capability is not self._capability:
            raise ValueError("adapter queried for an unrelated capability")
        if self._bridge_available:
            status = HardwareStatus.NOT_CHECKED
            message = (
                "Native bridge terpasang; perangkat dan permission perlu diperiksa "
                "saat runtime."
            )
        else:
            status = HardwareStatus.UNSUPPORTED
            message = "Native bridge belum disertakan dalam build platform ini."
        return CapabilityInfo(
            capability=capability,
            platform=self._platform,
            status=status,
            message=message,
            details={"native_bridge_available": self._bridge_available},
            checked_at=datetime.now(UTC),
        )
