"""Framework-independent application lifecycle state machine."""

from __future__ import annotations

from collections.abc import Callable
from enum import StrEnum

from app.core.errors import ApplicationError, ErrorCode


class LifecycleState(StrEnum):
    INITIALIZING = "initializing"
    RUNNING = "running"
    STOPPING = "stopping"
    STOPPED = "stopped"
    FAILED = "failed"


LifecycleListener = Callable[[LifecycleState], None]


class AppLifecycle:
    """Tracks application startup and shutdown without depending on Qt."""

    def __init__(self) -> None:
        self._state = LifecycleState.INITIALIZING
        self._listeners: list[LifecycleListener] = []

    @property
    def state(self) -> LifecycleState:
        return self._state

    def subscribe(self, listener: LifecycleListener) -> None:
        """Subscribe to state changes. Duplicate subscriptions are ignored."""
        if listener not in self._listeners:
            self._listeners.append(listener)

    def _set_state(self, state: LifecycleState) -> None:
        if state == self._state:
            return
        self._state = state
        for listener in tuple(self._listeners):
            listener(state)

    def mark_running(self) -> None:
        if self._state is not LifecycleState.INITIALIZING:
            raise ApplicationError(
                ErrorCode.INVALID_STATE,
                f"Cannot enter running state from '{self._state.value}'.",
                recoverable=False,
            )
        self._set_state(LifecycleState.RUNNING)

    def begin_shutdown(self) -> None:
        if self._state in (LifecycleState.STOPPING, LifecycleState.STOPPED):
            return
        if self._state is LifecycleState.FAILED:
            self._set_state(LifecycleState.STOPPED)
            return
        self._set_state(LifecycleState.STOPPING)

    def mark_stopped(self) -> None:
        if self._state is LifecycleState.STOPPED:
            return
        self._set_state(LifecycleState.STOPPED)

    def mark_failed(self) -> None:
        self._set_state(LifecycleState.FAILED)
