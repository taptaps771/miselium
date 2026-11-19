"""Tests for stable application error metadata."""

from app.core.errors import ApplicationError, ErrorCode


def test_application_error_exposes_safe_metadata() -> None:
    error = ApplicationError(
        ErrorCode.PERMISSION_DENIED,
        "Camera permission is required.",
        details={"capability": "camera"},
    )
    assert error.code is ErrorCode.PERMISSION_DENIED
    assert error.message == "Camera permission is required."
    assert error.details == {"capability": "camera"}
    assert error.recoverable is True
    assert "permission_denied" in str(error)
