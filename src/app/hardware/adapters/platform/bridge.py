"""Native bridge contracts and a safe dispatcher.

An Android implementation must be supplied by a packaged Java/Kotlin or C++/JNI extension.
Qt's QJniObject is a C++ API and is not assumed to be callable directly from Python.
"""

from __future__ import annotations

from typing import Protocol

from app.hardware.contracts.models import HardwareResult, PickedFile


class AndroidNativeBridge(Protocol):
    async def request_location(self) -> HardwareResult[dict[str, float]]: ...
    async def scan_ble(self, timeout_seconds: float) -> HardwareResult[list[dict[str, object]]]: ...
    async def read_nfc(self) -> HardwareResult[dict[str, object]]: ...
    async def authenticate_biometric(self, reason: str) -> HardwareResult[bool]: ...
    async def pick_document(self, mime_types: tuple[str, ...]) -> HardwareResult[PickedFile]: ...
    async def share_uri(self, uri: str) -> HardwareResult[None]: ...
