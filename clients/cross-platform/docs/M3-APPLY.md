# M3 baseline integration note

The M3 archive is the complete starter project at the point before the M4–M8 work. It includes M0, M1, and M2 rather than being a patch-only archive. Preserve the existing `.venv`, `.env`, `.git`, and local data when applying it to an existing Miselium checkout. Inspect `git status --short` and back up uncommitted work before replacing files.

The optional desktop image decoder is installed separately:

```bash
pip install -r requirements/scanner.txt
pytest -q
python scripts/check_hardware.py
python main.py
```

If no webcam is available, the camera capability may report `unavailable`; use **Pilih gambar** on the Camera & Scanner tab to test QR/barcode decoding from an existing image. If the optional ZXing dependencies are not installed, the UI reports `unsupported` and the rest of the app remains usable.
