"""Consistent console and rotating-file logging for the application."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from logging.handlers import RotatingFileHandler
from pathlib import Path

from platformdirs import user_log_dir

from app.config import AppSettings


@dataclass(frozen=True, slots=True)
class LoggingRuntime:
    logger: logging.Logger
    log_file: Path


def configure_logging(
    settings: AppSettings,
    *,
    log_directory: Path | None = None,
) -> LoggingRuntime:
    """Configure an isolated app logger with console and rotating-file handlers."""
    directory = log_directory or settings.log_dir or Path(
        user_log_dir(settings.app_name, appauthor=False)
    )
    directory.mkdir(parents=True, exist_ok=True)
    log_file = directory / "application.log"

    logger = logging.getLogger("miselium")
    logger.setLevel(settings.log_level)
    logger.propagate = False

    # Reconfiguration is safe in tests and when the app bootstrap is called again.
    for handler in tuple(logger.handlers):
        logger.removeHandler(handler)
        handler.close()

    formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    file_handler = RotatingFileHandler(
        log_file,
        maxBytes=2_000_000,
        backupCount=4,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    logger.info("Logging initialized (level=%s, file=%s)", settings.log_level, log_file)
    return LoggingRuntime(logger=logger, log_file=log_file)
