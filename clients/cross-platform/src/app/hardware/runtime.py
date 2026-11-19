"""Composition root for the platform-independent hardware abstraction layer."""

from __future__ import annotations

from dataclasses import dataclass

from app.hardware.adapters.platform.capabilities import (
    NativeBridgeCapabilityAdapter,
    QtModuleCapabilityAdapter,
)
from app.hardware.adapters.qt.camera import QtCameraCapabilityAdapter
from app.hardware.adapters.zxing.capability import ZXingCapabilityAdapter
from app.hardware.contracts.models import Capability, Platform
from app.hardware.permission_manager import PermissionManager, UnconfiguredPermissionProvider
from app.hardware.platform import detect_platform
from app.hardware.registry import CapabilityRegistry
from app.hardware.services.access_service import HardwareAccessService


@dataclass(frozen=True, slots=True)
class HardwareRuntime:
    registry: CapabilityRegistry
    permissions: PermissionManager
    access: HardwareAccessService


def create_hardware_runtime(platform: Platform | None = None) -> HardwareRuntime:
    """Create a safe runtime with no assumed hardware support or granted permissions."""
    active_platform = platform or detect_platform()
    registry = CapabilityRegistry(platform=active_platform)
    # M3 adapters are registered but only probed when the app explicitly checks capabilities.
    registry.register_adapter(QtCameraCapabilityAdapter(active_platform))
    registry.register_adapter(ZXingCapabilityAdapter(active_platform))
    registry.register_adapter(
        QtModuleCapabilityAdapter(
            active_platform, Capability.LOCATION, "PySide6.QtPositioning"
        )
    )
    registry.register_adapter(
        QtModuleCapabilityAdapter(
            active_platform, Capability.BLUETOOTH, "PySide6.QtBluetooth"
        )
    )
    registry.register_adapter(
        QtModuleCapabilityAdapter(active_platform, Capability.BLE, "PySide6.QtBluetooth")
    )
    # Native-only features remain explicitly unsupported until the Android bridge is packaged.
    for capability in (
        Capability.NFC,
        Capability.BIOMETRIC,
        Capability.PUSH_NOTIFICATIONS,
        Capability.FILE_ACCESS,
        Capability.FILE_SHARING,
    ):
        registry.register_adapter(
            NativeBridgeCapabilityAdapter(
                active_platform, capability, bridge_available=False
            )
        )
    permissions = PermissionManager(UnconfiguredPermissionProvider())
    access = HardwareAccessService(registry, permissions)
    return HardwareRuntime(registry=registry, permissions=permissions, access=access)
