"""Tests for application lifecycle transitions."""

import pytest

from app.core.errors import ApplicationError, ErrorCode
from app.core.lifecycle import AppLifecycle, LifecycleState


def test_lifecycle_start_and_stop() -> None:
    lifecycle = AppLifecycle()
    observed: list[str] = []
    lifecycle.subscribe(lambda state: observed.append(state.value))

    lifecycle.mark_running()
    lifecycle.begin_shutdown()
    lifecycle.mark_stopped()

    assert lifecycle.state is LifecycleState.STOPPED
    assert observed == ["running", "stopping", "stopped"]


def test_lifecycle_rejects_invalid_start_transition() -> None:
    lifecycle = AppLifecycle()
    lifecycle.mark_running()
    with pytest.raises(ApplicationError) as error:
        lifecycle.mark_running()
    assert error.value.code is ErrorCode.INVALID_STATE


def test_shutdown_is_idempotent() -> None:
    lifecycle = AppLifecycle()
    lifecycle.begin_shutdown()
    lifecycle.begin_shutdown()
    lifecycle.mark_stopped()
    lifecycle.mark_stopped()
    assert lifecycle.state is LifecycleState.STOPPED


def test_failed_lifecycle_can_finish_shutdown() -> None:
    lifecycle = AppLifecycle()
    lifecycle.mark_failed()
    lifecycle.begin_shutdown()
    assert lifecycle.state is LifecycleState.STOPPED
