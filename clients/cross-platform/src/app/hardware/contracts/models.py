"""Framework-independent value objects for the hardware abstraction layer."""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import UTC, datetime
from enum import StrEnum
from typing import Any


class Platform(StrEnum):
    ANDROID = "android"
    WINDOWS = "windows"
    LINUX = "linux"
    MACOS = "macos"
    UNKNOWN = "unknown"


class Capability(StrEnum):
    CAMERA = "camera"
    BARCODE_SCANNER = "barcode_scanner"
    LOCATION = "location"
    LOCATION_BACKGROUND = "location_background"
    BLUETOOTH = "bluetooth"
    BLE = "ble"
    NFC = "nfc"
    BIOMETRIC = "biometric"
    PUSH_NOTIFICATIONS = "push_notifications"
    FILE_ACCESS = "file_access"
    FILE_SHARING = "file_sharing"


class HardwareStatus(StrEnum):
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"
    UNSUPPORTED = "unsupported"
    PERMISSION_REQUIRED = "permission_required"
    PERMISSION_DENIED = "permission_denied"
    BUSY = "busy"
    ERROR = "error"
    NOT_CHECKED = "not_checked"


class Permission(StrEnum):
    CAMERA = "camera"
    LOCATION = "location"
    LOCATION_BACKGROUND = "location_background"
    BLUETOOTH_SCAN = "bluetooth_scan"
    BLUETOOTH_CONNECT = "bluetooth_connect"
    NFC = "nfc"
    BIOMETRIC = "biometric"
    NOTIFICATIONS = "notifications"
    FILE_READ = "file_read"
    FILE_WRITE = "file_write"
    FILE_SHARE = "file_share"


class PermissionStatus(StrEnum):
    GRANTED = "granted"
    DENIED = "denied"
    NOT_DETERMINED = "not_determined"
    RESTRICTED = "restricted"
    NOT_REQUIRED = "not_required"
    UNSUPPORTED = "unsupported"
    UNKNOWN = "unknown"


@dataclass(frozen=True, slots=True)
class CapabilityInfo:
    capability: Capability
    platform: Platform
    status: HardwareStatus = HardwareStatus.NOT_CHECKED
    message: str = ""
    details: dict[str, Any] = field(default_factory=dict)
    checked_at: datetime | None = None

    @classmethod
    def not_checked(cls, capability: Capability, platform: Platform) -> CapabilityInfo:
        return cls(
            capability=capability,
            platform=platform,
            status=HardwareStatus.NOT_CHECKED,
            message="Belum diperiksa; adapter platform belum melakukan probe.",
        )


@dataclass(frozen=True, slots=True)
class PermissionInfo:
    permission: Permission
    status: PermissionStatus
    message: str = ""
    can_ask_again: bool = False


@dataclass(frozen=True, slots=True)
class HardwareResult[T]:
    status: HardwareStatus
    data: T | None = None
    message: str = ""
    code: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def is_success(self) -> bool:
        return self.status is HardwareStatus.AVAILABLE


@dataclass(frozen=True, slots=True)
class ScanPayload:
    value: str
    format: str


@dataclass(frozen=True, slots=True)
class GeoPosition:
    latitude: float
    longitude: float
    accuracy_m: float | None = None
    captured_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    def __post_init__(self) -> None:
        if not math.isfinite(self.latitude) or not -90 <= self.latitude <= 90:
            raise ValueError("latitude must be finite and between -90 and 90")
        if not math.isfinite(self.longitude) or not -180 <= self.longitude <= 180:
            raise ValueError("longitude must be finite and between -180 and 180")
        if self.accuracy_m is not None and (
            not math.isfinite(self.accuracy_m) or self.accuracy_m < 0
        ):
            raise ValueError("accuracy_m must be finite and non-negative")


@dataclass(frozen=True, slots=True)
class BluetoothDevice:
    identifier: str
    name: str | None = None
    rssi: int | None = None


@dataclass(frozen=True, slots=True)
class NfcTag:
    identifier: str
    technologies: tuple[str, ...] = ()
    ndef_text: str | None = None


@dataclass(frozen=True, slots=True)
class BiometricAuth:
    authenticated: bool
    method: str | None = None


@dataclass(frozen=True, slots=True)
class PickedFile:
    """A selected file; `uri` is used instead of assuming a filesystem path."""

    uri: str
    name: str
    mime_type: str | None = None
    size_bytes: int | None = None
