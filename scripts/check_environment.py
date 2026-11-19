"""Check the Python and Qt modules needed by the first compatibility milestone."""

from __future__ import annotations

import importlib
import platform
import sys
from importlib.metadata import PackageNotFoundError, version

MODULES = {
    "QtCore": "PySide6.QtCore",
    "QtGui": "PySide6.QtGui",
    "QtQml": "PySide6.QtQml",
    "QtQuick": "PySide6.QtQuick",
    "QtMultimedia": "PySide6.QtMultimedia",
    "QtPositioning": "PySide6.QtPositioning",
    "QtBluetooth": "PySide6.QtBluetooth",
}


def main() -> int:
    print("=== Miselium: environment check ===")
    print(f"Python   : {platform.python_version()} ({sys.executable})")
    print(f"Platform : {platform.platform()}")
    try:
        print(f"PySide6  : {version('PySide6')}")
    except PackageNotFoundError:
        print("PySide6  : NOT INSTALLED")
        return 2

    failed = []
    for label, module_name in MODULES.items():
        try:
            importlib.import_module(module_name)
            print(f"[ OK ] {label}")
        except Exception as exc:  # report import/plugin issues without hiding them
            failed.append(label)
            print(f"[FAIL] {label}: {type(exc).__name__}: {exc}")

    if failed:
        print("\nSome modules could not be imported. Keep the exact error output for diagnosis.")
        return 1

    print("\nAll requested Python Qt module imports passed.")
    print("Note: import success does not yet prove physical camera/GPS/BLE hardware access.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
