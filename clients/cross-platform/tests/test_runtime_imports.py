"""Smoke tests for the Qt runtime imports used by the M0 prototype."""

import importlib

import pytest

pytest.importorskip("PySide6", reason="PySide6 is required for Qt runtime import tests")


@pytest.mark.parametrize(
    "module_name",
    [
        "PySide6.QtCore",
        "PySide6.QtGui",
        "PySide6.QtQml",
        "PySide6.QtQuick",
    ],
)
def test_required_qt_module_imports(module_name: str) -> None:
    assert importlib.import_module(module_name) is not None
