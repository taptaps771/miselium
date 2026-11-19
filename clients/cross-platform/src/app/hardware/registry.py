"""Capability registry used to discover platform-specific hardware support."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Callable, Iterable
from datetime import UTC, datetime

from app.hardware.contracts.adapters import CapabilityAdapter
from app.hardware.contracts.models import Capability, CapabilityInfo, HardwareStatus, Platform
from app.hardware.platform import detect_platform

RegistryListener = Callable[[CapabilityInfo], None]


class CapabilityRegistry:
    """Tracks capability status without making assumptions about attached hardware."""

    def __init__(self, platform: Platform | None = None) -> None:
        self.platform = platform or detect_platform()
        self._adapters: dict[Capability, CapabilityAdapter] = {}
        self._items = {
            capability: CapabilityInfo.not_checked(capability, self.platform)
            for capability in Capability
        }
        self._listeners: list[RegistryListener] = []
        self._logger = logging.getLogger("miselium.hardware.registry")

    def subscribe(self, listener: RegistryListener) -> None:
        if listener not in self._listeners:
            self._listeners.append(listener)

    def register_adapter(
        self,
        adapter: CapabilityAdapter,
        capabilities: Iterable[Capability] | None = None,
    ) -> None:
        selected = tuple(capabilities if capabilities is not None else adapter.capabilities)
        if not selected:
            raise ValueError("adapter must declare at least one capability")
        if adapter.platform is not self.platform:
            raise ValueError(
                f"adapter platform '{adapter.platform.value}' does not match "
                f"registry platform '{self.platform.value}'"
            )
        duplicates = [item.value for item in selected if item in self._adapters]
        if duplicates:
            raise ValueError(f"capability already has an adapter: {', '.join(duplicates)}")
        for capability in selected:
            self._adapters[capability] = adapter

    def get(self, capability: Capability) -> CapabilityInfo:
        return self._items[capability]

    def snapshot(self) -> tuple[CapabilityInfo, ...]:
        return tuple(self._items[capability] for capability in Capability)

    async def probe(self, capability: Capability) -> CapabilityInfo:
        adapter = self._adapters.get(capability)
        if adapter is None:
            return self._items[capability]
        try:
            info = await adapter.probe(capability)
            if info.capability is not capability:
                raise ValueError("adapter returned information for a different capability")
            if info.platform is not self.platform:
                raise ValueError("adapter returned information for a different platform")
            if info.checked_at is None:
                info = CapabilityInfo(
                    capability=info.capability,
                    platform=info.platform,
                    status=info.status,
                    message=info.message,
                    details=dict(info.details),
                    checked_at=datetime.now(UTC),
                )
        except Exception as exc:  # An adapter failure must not crash the app.
            self._logger.exception("Capability probe failed: %s", capability.value)
            info = CapabilityInfo(
                capability=capability,
                platform=self.platform,
                status=HardwareStatus.ERROR,
                message="Capability probe failed.",
                details={"exception_type": type(exc).__name__},
                checked_at=datetime.now(UTC),
            )
        self._items[capability] = info
        for listener in tuple(self._listeners):
            try:
                listener(info)
            except Exception:
                self._logger.exception("Capability registry listener failed")
        return info

    async def probe_all(self) -> tuple[CapabilityInfo, ...]:
        await asyncio.gather(*(self.probe(capability) for capability in self._adapters))
        return self.snapshot()
