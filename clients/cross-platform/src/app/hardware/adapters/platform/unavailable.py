"""Explicit fallback services for platform features without a native bridge.

These adapters deliberately return UNSUPPORTED. They never simulate successful hardware
operations in production, and keep the desktop client usable when a feature is Android-only.
"""

from __future__ import annotations

from app.hardware.contracts.models import (
    BiometricAuth,
    BluetoothDevice,
    GeoPosition,
    HardwareResult,
    HardwareStatus,
    NfcTag,
    PickedFile,
)


class UnsupportedLocationService:
    async def current_position(self) -> HardwareResult[GeoPosition]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="Native location provider belum dikonfigurasi.",
            code="location_bridge_missing",
        )

    async def start_tracking(self) -> HardwareResult[None]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="Background location memerlukan native platform service.",
            code="location_bridge_missing",
        )

    async def stop_tracking(self) -> HardwareResult[None]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="Location tracking tidak aktif.",
            code="location_not_configured",
        )


class UnsupportedBluetoothService:
    async def scan(
        self,
        *,
        timeout_seconds: float = 10.0,
    ) -> HardwareResult[tuple[BluetoothDevice, ...]]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="BLE scan memerlukan native platform adapter.",
            code="ble_bridge_missing",
        )

    async def connect(self, identifier: str) -> HardwareResult[None]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="BLE connection memerlukan native platform adapter.",
            code="ble_bridge_missing",
        )


class UnsupportedNfcService:
    async def read_tag(self) -> HardwareResult[NfcTag]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="NFC ReaderMode belum dihubungkan ke Android native bridge.",
            code="nfc_bridge_missing",
        )


class UnsupportedBiometricService:
    async def authenticate(self, reason: str) -> HardwareResult[BiometricAuth]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="BiometricPrompt belum dihubungkan ke AndroidX bridge.",
            code="biometric_bridge_missing",
        )


class UnsupportedFileService:
    async def pick_file(
        self,
        mime_types: tuple[str, ...] = (),
    ) -> HardwareResult[PickedFile]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="File picker platform belum dikonfigurasi.",
            code="file_picker_missing",
        )

    async def share_file(self, uri: str) -> HardwareResult[None]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="Native share intent belum dikonfigurasi.",
            code="share_bridge_missing",
        )


class UnsupportedNotificationService:
    async def show_local(self, title: str, body: str) -> HardwareResult[None]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="Local notification adapter belum dikonfigurasi.",
            code="local_notification_missing",
        )

    async def register_push_token(self) -> HardwareResult[str]:
        return HardwareResult(
            HardwareStatus.UNSUPPORTED,
            message="Push token harus diperoleh dari native FCM SDK.",
            code="push_provider_missing",
        )
