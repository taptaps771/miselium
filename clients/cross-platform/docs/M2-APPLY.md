# Apply M2 to an existing M1 checkout

The M2 ZIP contains the complete starter project. To apply it over an existing M1 checkout:

1. Open a terminal at the existing project root and make sure your changes are committed or backed up.
2. Extract the ZIP to a temporary directory.
3. Copy the contents of the extracted `cross-platform-starter-m2/` directory into the existing project root, allowing the M2 files to replace their M1 counterparts.
4. Keep using the existing `.venv`; do not recreate it.
5. Run the validation commands below.

```bash
pip install -r requirements-dev.txt
pytest -q
ruff check .
python scripts/check_hardware.py
python main.py
```

The project `pyproject.toml` still targets Python `>=3.14,<3.15`. M2 introduces no new third-party runtime dependency; the HAL contracts and registry use the Python standard library.

Before applying the package to a repository with uncommitted work, inspect `git status --short` and make a backup. The archive replaces the QML dashboard, application controller, bootstrap, README, architecture documentation, configuration version, and project version while adding the hardware package and tests.
