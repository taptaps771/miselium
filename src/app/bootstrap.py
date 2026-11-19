"""Application composition root: settings, logging, Qt, and QML."""

from __future__ import annotations

import asyncio
import logging
import sys
from collections.abc import Sequence
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from app.application.app_controller import AppController
from app.config import AppSettings, get_settings
from app.core.lifecycle import AppLifecycle
from app.core.logging_config import configure_logging
from app.hardware.runtime import create_hardware_runtime

QML_MAIN = Path(__file__).resolve().parent / "ui" / "Main.qml"


def run_application(
    argv: Sequence[str] | None = None,
    *,
    settings: AppSettings | None = None,
) -> int:
    """Create and run the Qt application. Returns the process exit code."""
    active_settings = settings or get_settings()
    logging_runtime = configure_logging(active_settings)
    logger: logging.Logger = logging_runtime.logger

    logger.info(
        "Starting %s %s (environment=%s)",
        active_settings.app_name,
        active_settings.app_version,
        active_settings.environment,
    )

    app = QGuiApplication(list(argv) if argv is not None else sys.argv)
    app.setApplicationName(active_settings.app_name)
    app.setApplicationVersion(active_settings.app_version)
    app.setOrganizationName("Miselium")

    lifecycle = AppLifecycle()
    engine = QQmlApplicationEngine()
    hardware_runtime = create_hardware_runtime()
    # Probe adapters before exposing the initial capability inventory to QML.
    asyncio.run(hardware_runtime.registry.probe_all())
    controller = AppController(
        active_settings,
        lifecycle,
        logging_runtime.log_file,
        engine,
        hardware_runtime=hardware_runtime,
    )
    logger.info(
        "Hardware abstraction initialized for platform=%s with %s declared capabilities",
        hardware_runtime.registry.platform.value,
        len(hardware_runtime.registry.snapshot()),
    )
    engine.rootContext().setContextProperty("appController", controller)

    app.aboutToQuit.connect(controller.shutdown)
    app.aboutToQuit.connect(lifecycle.mark_stopped)
    lifecycle.subscribe(
        lambda state: logger.info("Application lifecycle: %s", state.value)
    )

    if not QML_MAIN.is_file():
        logger.error("QML entry point not found: %s", QML_MAIN)
        lifecycle.mark_failed()
        return 2

    engine.load(QUrl.fromLocalFile(str(QML_MAIN)))
    if not engine.rootObjects():
        logger.error("QML failed to load: %s", QML_MAIN)
        lifecycle.mark_failed()
        return 3

    lifecycle.mark_running()
    logger.info("Application started")
    exit_code = app.exec()
    logger.info("Application event loop finished (exit_code=%s)", exit_code)
    return exit_code
