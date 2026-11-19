"""Contracts implemented by platform-specific capability adapters."""

from __future__ import annotations

from collections.abc import Iterable
from typing import Protocol

from app.hardware.contracts.models import Capability, CapabilityInfo, Platform


class CapabilityAdapter(Protocol):
    @property
    def platform(self) -> Platform: ...

    @property
    def capabilities(self) -> Iterable[Capability]: ...

    async def probe(self, capability: Capability) -> CapabilityInfo: ...
