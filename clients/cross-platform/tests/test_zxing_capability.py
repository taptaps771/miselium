from __future__ import annotations

import pytest

from app.hardware.adapters.zxing.capability import ZXingCapabilityAdapter
from app.hardware.contracts.models import Capability, HardwareStatus, Platform


@pytest.mark.asyncio
async def test_zxing_capability_is_available_when_all_bindings_exist(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.hardware.adapters.zxing.capability.importlib.util.find_spec",
        lambda _name: object(),
    )
    adapter = ZXingCapabilityAdapter(Platform.LINUX)

    result = await adapter.probe(Capability.BARCODE_SCANNER)

    assert result.status is HardwareStatus.AVAILABLE
    assert result.details["missing_modules"] == []


@pytest.mark.asyncio
async def test_zxing_capability_reports_missing_modules(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.hardware.adapters.zxing.capability.importlib.util.find_spec",
        lambda name: None if name == "zxingcpp" else object(),
    )
    adapter = ZXingCapabilityAdapter(Platform.LINUX)

    result = await adapter.probe(Capability.BARCODE_SCANNER)

    assert result.status is HardwareStatus.UNSUPPORTED
    assert result.details["missing_modules"] == ["zxingcpp"]
