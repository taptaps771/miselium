"""Print the HAL capability inventory without accessing physical hardware."""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_DIRECTORY = PROJECT_ROOT / "src"
if str(SRC_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(SRC_DIRECTORY))

from app.hardware.runtime import create_hardware_runtime  # noqa: E402


def main() -> int:
    runtime = create_hardware_runtime()
    asyncio.run(runtime.registry.probe_all())
    print("=== Hardware Abstraction Layer check ===")
    print(f"Platform     : {runtime.registry.platform.value}")
    print(f"Capabilities : {len(runtime.registry.snapshot())}")
    print("M3 probe checks camera devices and the optional ZXing decoder; no camera is activated.")
    for info in runtime.registry.snapshot():
        print(f"[ {info.status.value.upper():11} ] {info.capability.value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
