"""Static validation of the Android manifest template and declared permissions."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "platforms" / "android" / "AndroidManifest.xml"
REQUIRED = {
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.BLUETOOTH_SCAN",
    "android.permission.BLUETOOTH_CONNECT",
    "android.permission.NFC",
    "android.permission.POST_NOTIFICATIONS",
}


def main() -> int:
    root = ET.parse(MANIFEST).getroot()
    namespace = "{http://schemas.android.com/apk/res/android}"
    declared = {node.attrib.get(namespace + "name", "") for node in root.findall("uses-permission")}
    missing = sorted(REQUIRED - declared)
    if missing:
        raise SystemExit("Missing Android permissions: " + ", ".join(missing))
    print(f"Android manifest OK ({len(declared)} permission declarations).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
