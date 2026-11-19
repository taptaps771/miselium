from __future__ import annotations

import json
import os
import uuid
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import pytest
from PySide6.QtCore import QCoreApplication, QSettings, QUrl
from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent, QQmlExpression

UI_DIR = Path(__file__).resolve().parents[1] / "src" / "app" / "ui"
THEME_CONTROLLER = UI_DIR / "ThemeController.qml"
SETTINGS_PAGE = UI_DIR / "SettingsPage.qml"


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


def test_apply_anchor_updates_one_color_and_marks_palette_custom(theme_controller):
    engine, controller = theme_controller
    original_brand = controller.property("brand")

    assert evaluate(engine, controller, 'auditController.applyAnchor("brand", "#a1b2c3")') is True
    assert controller.property("brand") == "#A1B2C3"
    assert controller.property("palette") == "Custom"

    assert evaluate(engine, controller, 'auditController.applyAnchor("brand", "#12GG56")') is False
    assert controller.property("brand") == "#A1B2C3"
    assert controller.property("brand") != original_brand
    assert evaluate(engine, controller, 'auditController.applyAnchor("unknown", "#112233")') is False


def test_saved_theme_restores_palette_identity(theme_controller):
    engine, controller = theme_controller
    controller.setProperty("style", "Aurora")
    controller.setProperty("mode", "Dark")
    assert evaluate(engine, controller, 'auditController.applyCustomAnchors("#112233", "#445566", "#778899", "#AABBCC")')
    assert evaluate(engine, controller, 'auditController.saveTheme("Audit Theme")')

    controller.setProperty("palette", "Office Blue")
    assert evaluate(engine, controller, 'auditController.applySavedTheme("Audit Theme")')
    assert controller.property("palette") == "Custom"
    assert controller.property("brand") == "#112233"
    assert controller.property("style") == "Aurora"


def test_removed_glassmorphism_style_falls_back_to_default(theme_controller):
    engine, controller = theme_controller
    controller.setProperty(
        "savedThemesJson",
        json.dumps(
            [
                {
                    "name": "Legacy Glass",
                    "style": "Glassmorphism",
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

    assert evaluate(engine, controller, 'auditController.applySavedTheme("Legacy Glass")')
    assert controller.property("style") == "Industrial Professional"
    assert controller.property("brand") == "#112233"
    assert evaluate(engine, controller, 'auditController.availableStyles.indexOf("Glassmorphism")') == -1


def test_settings_page_exposes_theme_application_menu(theme_controller):
    engine, controller = theme_controller
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(SETTINGS_PAGE)))
    page = component.createWithInitialProperties({
        "themeController": controller,
        "width": 1180,
        "height": 820,
    })
    assert page is not None, [error.toString() for error in component.errors()]
    assert page.property("activeSection") == "theme"

    nav_items = page.property("navItems").toVariant()
    assert nav_items[0]["code"] == "theme"
    assert nav_items[0]["title"] == "Tema Aplikasi"