from __future__ import annotations

import json
import os
import uuid
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import pytest
from PySide6.QtCore import QCoreApplication, QSettings, QUrl
from PySide6.QtQml import QQmlApplicationEngine, QQmlExpression

THEME_CONTROLLER = Path(__file__).resolve().parents[1] / "src" / "app" / "ui" / "ThemeController.qml"


@pytest.fixture
def theme_controller(qapp, tmp_path):
    application = QCoreApplication.instance()
    application.setOrganizationName(f"MiseliumTests-{uuid.uuid4().hex}")
    application.setOrganizationDomain("tests.miselium.invalid")
    application.setApplicationName("ThemeController")
    QSettings.setDefaultFormat(QSettings.IniFormat)
    QSettings.setPath(QSettings.IniFormat, QSettings.UserScope, str(tmp_path))

    engine = QQmlApplicationEngine()
    engine.load(QUrl.fromLocalFile(str(THEME_CONTROLLER)))
    assert engine.rootObjects(), "ThemeController.qml failed to load"
    yield engine, engine.rootObjects()[0]
    engine.deleteLater()


def evaluate(engine: QQmlApplicationEngine, controller, expression: str):
    context = engine.rootContext()
    context.setContextProperty("auditController", controller)
    qml_expression = QQmlExpression(context, None, expression)
    value, is_undefined = qml_expression.evaluate()
    assert not qml_expression.hasError(), qml_expression.error().toString()
    assert not is_undefined
    return value


def _luminance(color) -> float:
    channels = [color.redF(), color.greenF(), color.blueF()]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def test_custom_palette_rejects_invalid_hex_and_normalizes_valid_colors(theme_controller):
    engine, controller = theme_controller
    original_brand = controller.property("brand")

    assert evaluate(engine, controller, 'auditController.isHex("#a1B2c3")') is True
    assert evaluate(engine, controller, 'auditController.isHex("#12GG56")') is False
    assert evaluate(engine, controller, 'auditController.isHex("#11223344")') is False
    assert evaluate(
        engine,
        controller,
        'auditController.applyCustomAnchors("#12GG56", "#112233", "#445566", "#778899")',
    ) is False
    assert controller.property("brand") == original_brand

    assert evaluate(
        engine,
        controller,
        'auditController.applyCustomAnchors("#112233", "#445566", "#778899", "#AABBCC")',
    ) is True
    assert controller.property("brand") == "#112233"
    assert controller.property("palette") == "Custom"


def test_dark_clay_surfaces_keep_text_contrast_and_aurora_has_its_own_tokens(theme_controller):
    _, controller = theme_controller
    controller.setProperty("style", "Claymorphism")
    controller.setProperty("mode", "Dark")
    panel = controller.property("panel")
    text = controller.property("text")
    lighter, darker = sorted((_luminance(panel), _luminance(text)), reverse=True)
    assert (lighter + 0.05) / (darker + 0.05) >= 4.5

    controller.setProperty("style", "Aurora")
    controller.setProperty("mode", "Light")
    assert controller.property("window").name() == "#f3f1fa"
    assert controller.property("panel").name() == "#fcfbff"
    assert controller.property("border").name() == "#d8d2e8"


def test_saved_theme_restores_palette_identity_and_image_preview(theme_controller):
    engine, controller = theme_controller
    controller.setProperty("style", "Glassmorphism")
    controller.setProperty("mode", "Dark")
    controller.setProperty("glassPreviewImage", "file:///tmp/theme-preview.png")
    assert evaluate(engine, controller, 'auditController.applyCustomAnchors("#112233", "#445566", "#778899", "#AABBCC")')
    assert evaluate(engine, controller, 'auditController.saveTheme("Audit Theme")')

    controller.setProperty("palette", "Office Blue")
    controller.setProperty("glassPreviewImage", "")
    assert evaluate(engine, controller, 'auditController.applySavedTheme("Audit Theme")')
    assert controller.property("palette") == "Custom"
    assert controller.property("brand") == "#112233"
    assert controller.property("glassPreviewImage") == "file:///tmp/theme-preview.png"

def test_legacy_saved_theme_uses_bounded_glass_defaults(theme_controller):
    engine, controller = theme_controller
    controller.setProperty(
        "savedThemesJson",
        json.dumps(
            [
                {
                    "name": "Legacy",
                    "style": "Industrial Professional",
                    "mode": "Dark",
                    "palette": "Custom",
                    "brand": "#112233",
                    "accent": "#445566",
                    "background": "#778899",
                    "border": "#AABBCC",
                    "glassBlur": 999,
                    "glassOpacity": -1,
                }
            ]
        ),
    )

    assert evaluate(engine, controller, 'auditController.applySavedTheme("Legacy")')
    assert controller.property("glassBlur") == 40
    assert controller.property("glassOpacity") == 0.05
    assert controller.property("glassBorderOpacity") == 0.30
    assert controller.property("glassRadius") == 16
    assert controller.property("glassSaturation") == 100