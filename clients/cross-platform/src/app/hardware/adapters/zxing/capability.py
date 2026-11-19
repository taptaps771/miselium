"""Capability probe for the optional ZXing-C++ Python binding."""

from __future__ import annotations

import importlib.util
from datetime import UTC, datetime

from app.hardware.contracts.models import Capability, CapabilityInfo, HardwareStatus, Platform


class ZXingCapabilityAdapter:
    def __init__(self, platform: Platform) -> None:
        self._platform = platform

    @property
    def platform(self) -> Platform:
        return self._platform

    @property
    def capabilities(self) -> tuple[Capability, ...]:
        return (Capability.BARCODE_SCANNER,)

    async def probe(self, capability: Capability) -> CapabilityInfo:
        if capability is not Capability.BARCODE_SCANNER:
            raise ValueError("ZXingCapabilityAdapter only supports barcode_scanner")
        required_modules = ("zxingcpp", "numpy", "PIL")
        missing = [name for name in required_modules if importlib.util.find_spec(name) is None]
        status = HardwareStatus.UNSUPPORTED if missing else HardwareStatus.AVAILABLE
        message = (
            "Decoder ZXing-C++ siap digunakan."
            if not missing
            else "Dependensi scanner belum lengkap: " + ", ".join(missing)
        )
        return CapabilityInfo(
            capability=capability,
            platform=self._platform,
            status=status,
            message=message,
            details={"decoder": "ZXing-C++", "missing_modules": missing},
            checked_at=datetime.now(UTC),
        )
