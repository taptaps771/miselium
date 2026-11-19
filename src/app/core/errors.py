"""Application-level errors with stable codes suitable for UI and API mapping."""

from __future__ import annotations

from enum import StrEnum
from typing import Any


class ErrorCode(StrEnum):
    CONFIGURATION = "configuration_error"
    NETWORK = "network_error"
    PERMISSION_DENIED = "permission_denied"
    UNSUPPORTED = "unsupported"
    HARDWARE_UNAVAILABLE = "hardware_unavailable"
    INVALID_STATE = "invalid_state"
    VALIDATION = "validation_error"
    UNKNOWN = "unknown_error"


class ApplicationError(Exception):
    """Expected application error that can be safely translated for the user."""

    def __init__(
        self,
        code: ErrorCode,
        message: str,
        *,
        details: dict[str, Any] | None = None,
        recoverable: bool = True,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details or {}
        self.recoverable = recoverable

    def __str__(self) -> str:
        return f"{self.code.value}: {self.message}"
