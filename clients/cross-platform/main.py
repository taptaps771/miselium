"""Executable entry point for the Miselium."""

from __future__ import annotations

import logging
import sys
from pathlib import Path

# Support direct execution from a source checkout without requiring pip install -e .
PROJECT_ROOT = Path(__file__).resolve().parent
SRC_DIRECTORY = PROJECT_ROOT / "src"
if str(SRC_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(SRC_DIRECTORY))

from app.bootstrap import run_application  # noqa: E402


def main() -> int:
    try:
        return run_application()
    except Exception:
        logging.basicConfig(level=logging.ERROR)
        logging.getLogger("miselium").exception(
            "Unrecoverable error while starting the application"
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
