from __future__ import annotations

from types import SimpleNamespace

import pytest

from app.hardware.adapters.zxing.barcode_scanner import ZXingBarcodeScanner
from app.hardware.contracts.models import HardwareStatus


@pytest.mark.asyncio
async def test_scanner_returns_structured_payloads_from_decoder() -> None:
    scanner = ZXingBarcodeScanner(
        decoder=lambda _data: [
            SimpleNamespace(text="https://example.test", format="QRCode"),
            SimpleNamespace(text="123456789", format="EAN13"),
        ]
    )

    result = await scanner.scan_image(b"image-bytes")

    assert result.status is HardwareStatus.AVAILABLE
    assert result.data is not None
    assert [(item.value, item.format) for item in result.data] == [
        ("https://example.test", "QRCode"),
        ("123456789", "EAN13"),
    ]
    assert result.metadata["count"] == 2


@pytest.mark.asyncio
async def test_scanner_reports_successful_empty_scan() -> None:
    scanner = ZXingBarcodeScanner(decoder=lambda _data: [])

    result = await scanner.scan_image(b"image-bytes")

    assert result.status is HardwareStatus.AVAILABLE
    assert result.data == ()
    assert result.code == "no_barcode_found"


@pytest.mark.asyncio
async def test_scanner_rejects_empty_or_oversized_images() -> None:
    scanner = ZXingBarcodeScanner(max_image_bytes=4, decoder=lambda _data: [])

    empty = await scanner.scan_image(b"")
    oversized = await scanner.scan_image(b"12345")

    assert empty.status is HardwareStatus.ERROR
    assert empty.code == "empty_image"
    assert oversized.status is HardwareStatus.ERROR
    assert oversized.code == "image_too_large"


@pytest.mark.asyncio
async def test_scanner_contains_decoder_exceptions() -> None:
    def broken_decoder(_data: bytes) -> list[object]:
        raise RuntimeError("decoder crashed")

    result = await ZXingBarcodeScanner(decoder=broken_decoder).scan_image(b"image-bytes")

    assert result.status is HardwareStatus.ERROR
    assert result.code == "decoder_error"
    assert result.metadata["exception_type"] == "RuntimeError"
