"""Optional QR/barcode image decoder backed by ZXing-C++.

The decoder works on image bytes, so callers do not need to expose filesystem paths to the
hardware layer. The package is optional and is installed from requirements/scanner.txt.
"""

from __future__ import annotations

from collections.abc import Callable, Iterable
from dataclasses import dataclass
from io import BytesIO

from app.hardware.contracts.models import HardwareResult, HardwareStatus, ScanPayload

DecodedBarcode = object
BarcodeDecoder = Callable[[bytes], Iterable[DecodedBarcode]]


@dataclass(slots=True)
class ZXingBarcodeScanner:
    """Decode one image into zero or more structured QR/barcode payloads."""

    decoder: BarcodeDecoder | None = None
    max_image_bytes: int = 20 * 1024 * 1024

    async def scan_image(self, image_bytes: bytes) -> HardwareResult[tuple[ScanPayload, ...]]:
        if not isinstance(image_bytes, bytes) or not image_bytes:
            return HardwareResult(
                status=HardwareStatus.ERROR,
                message="Data gambar kosong atau tidak valid.",
                code="empty_image",
            )
        if len(image_bytes) > self.max_image_bytes:
            return HardwareResult(
                status=HardwareStatus.ERROR,
                message=f"Ukuran gambar melebihi batas {self.max_image_bytes // (1024 * 1024)} MB.",
                code="image_too_large",
                metadata={"size_bytes": len(image_bytes)},
            )

        try:
            decoded = list(self.decoder(image_bytes) if self.decoder else self._decode_with_zxing(image_bytes))
        except ImportError as exc:
            return HardwareResult(
                status=HardwareStatus.UNSUPPORTED,
                message=(
                    "Scanner belum terpasang. Instal dependensi dengan "
                    "'pip install -r requirements/scanner.txt'."
                ),
                code="scanner_dependency_missing",
                metadata={"missing_module": str(exc)},
            )
        except (OSError, ValueError) as exc:
            return HardwareResult(
                status=HardwareStatus.ERROR,
                message="File bukan gambar yang valid atau tidak dapat dibaca.",
                code="invalid_image",
                metadata={"exception_type": type(exc).__name__},
            )
        except Exception as exc:  # A decoder failure must not escape into the UI layer.
            return HardwareResult(
                status=HardwareStatus.ERROR,
                message="Proses pembacaan QR/barcode gagal.",
                code="decoder_error",
                metadata={"exception_type": type(exc).__name__},
            )

        payloads: list[ScanPayload] = []
        for barcode in decoded:
            value = getattr(barcode, "text", None)
            if value is None or not str(value):
                continue
            barcode_format = getattr(barcode, "format", "UNKNOWN")
            payloads.append(ScanPayload(value=str(value), format=str(barcode_format)))

        if not payloads:
            return HardwareResult(
                status=HardwareStatus.AVAILABLE,
                data=(),
                message="Tidak ditemukan QR code atau barcode pada gambar.",
                code="no_barcode_found",
            )

        return HardwareResult(
            status=HardwareStatus.AVAILABLE,
            data=tuple(payloads),
            message=f"Berhasil membaca {len(payloads)} kode.",
            metadata={"count": len(payloads)},
        )

    @staticmethod
    def _decode_with_zxing(image_bytes: bytes) -> Iterable[DecodedBarcode]:
        import numpy as np
        import zxingcpp
        from PIL import Image

        with Image.open(BytesIO(image_bytes)) as image:
            rgb_image = image.convert("RGB")
            pixels = np.asarray(rgb_image)
        return zxingcpp.read_barcodes(pixels)
