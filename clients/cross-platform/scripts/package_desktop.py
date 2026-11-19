"""Build a desktop distribution with PyInstaller (Linux or Windows)."""

from __future__ import annotations

import argparse
import os
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clean", action="store_true", help="clean PyInstaller build cache")
    args = parser.parse_args()
    try:
        import PyInstaller.__main__
    except ImportError:
        parser.error(
            "Install packaging dependencies first: "
            "pip install -r requirements/package.txt"
        )
    root = Path(__file__).resolve().parents[1]
    separator = ";" if os.name == "nt" else ":"
    command = [
        str(root / "main.py"),
        "--name=Miselium",
        "--windowed",
        "--noconfirm",
        f"--paths={root / 'src'}",
        f"--add-data={root / 'src' / 'app' / 'ui'}{separator}app/ui",
        "--collect-all=PySide6.QtQml",
        "--collect-all=PySide6.QtQuick",
        "--collect-all=PySide6.QtMultimedia",
        "--collect-all=PySide6.QtPositioning",
        "--collect-all=PySide6.QtBluetooth",
    ]
    if args.clean:
        command.append("--clean")
    os.chdir(root)
    PyInstaller.__main__.run(command)
    artifact_name = "Miselium.exe" if os.name == "nt" else "Miselium"
    print(f"Desktop bundle created under: {root / 'dist' / artifact_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
