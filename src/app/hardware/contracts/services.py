"""Asynchronous feature-level hardware service contracts.

These protocols intentionally contain no Qt, Android, or operating-system imports.
Concrete implementations are added in later milestones.
"""

from __future__ import annotations

from typing import Protocol

from app.hardware.contracts.models import (
    BiometricAuth,
    BluetoothDevice,
    GeoPosition,
    HardwareResult,
    NfcTag,
    PickedFile,
    ScanPayload,
)


class CameraService(Protocol):
    async def capture(self) -> HardwareResult[bytes]: ...


class BarcodeScannerService(Protocol):
    async def scan_image(
        self, image_bytes: bytes
    ) -> HardwareResult[tuple[ScanPayload, ...]]: ...


class LocationService(Protocol):
    async def current_position(self) -> HardwareResult[GeoPosition]: ...

    async def start_tracking(self) -> HardwareResult[None]: ...

    async def stop_tracking(self) -> HardwareResult[None]: ...


class BluetoothService(Protocol):
    async def scan(
        self,
        *,
        timeout_seconds: float = 10.0,
    ) -> HardwareResult[tuple[BluetoothDevice, ...]]: ...

    async def connect(self, identifier: str) -> HardwareResult[None]: ...


class NfcService(Protocol):
    async def read_tag(self) -> HardwareResult[NfcTag]: ...


class BiometricService(Protocol):
    async def authenticate(self, reason: str) -> HardwareResult[BiometricAuth]: ...


class NotificationService(Protocol):
    async def show_local(self, title: str, body: str) -> HardwareResult[None]: ...

    async def register_push_token(self) -> HardwareResult[str]: ...


class FileService(Protocol):
    async def pick_file(self, mime_types: tuple[str, ...] = ()) -> HardwareResult[PickedFile]: ...

    async def share_file(self, uri: str) -> HardwareResult[None]: ...
