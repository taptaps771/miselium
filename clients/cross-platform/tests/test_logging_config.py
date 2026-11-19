"""Tests for log directory creation and file output."""

from pathlib import Path

from app.config import AppSettings
from app.core.logging_config import configure_logging


def test_logging_creates_file_and_writes_message(tmp_path: Path) -> None:
    runtime = configure_logging(
        AppSettings(_env_file=None),
        log_directory=tmp_path / "logs",
    )
    runtime.logger.info("m1 test log marker")
    for handler in runtime.logger.handlers:
        handler.flush()

    assert runtime.log_file.is_file()
    assert "m1 test log marker" in runtime.log_file.read_text(encoding="utf-8")
