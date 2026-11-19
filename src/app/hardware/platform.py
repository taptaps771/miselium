"""Host platform identification without importing Qt or native SDKs."""

from __future__ import annotations

import sys

from app.hardware.contracts.models import Platform


def detect_platform() -> Platform:
    """Detect the current runtime family, including Android Python builds."""
    if hasattr(sys, "getandroidapilevel"):
        return Platform.ANDROID
    if sys.platform.startswith("win"):
        return Platform.WINDOWS
    if sys.platform.startswith("linux"):
        return Platform.LINUX
    if sys.platform == "darwin":
        return Platform.MACOS
    return Platform.UNKNOWN
