# Miselium milestone status — M0 through M8

## Included source

This checkout is based on the complete M3 archive (which includes the M0, M1, and M2 source) and adds the M4–M8 foundations. It does not replace the original hardware contracts or camera/scanner implementation.

## Implemented code

- M0–M3: inherited client, QML, HAL, camera, and scanner source.
- M4: location/BLE capability probes, typed contracts, and safe fallback services.
- M5: NFC/biometric/file/share contracts, Android bridge protocol, and fail-closed fallbacks.
- M6: notification contract/fallback and tenant-scoped device token registration API.
- M7: FastAPI service, SQLAlchemy schema, Alembic migration, password hashing, JWT access tokens, workspace registration/login/listing, workspace invitations, tenant-scoped records, plan quota foundation, device registration, and async client wrapper.
- M8: Linux/Windows CI and PyInstaller package workflow definitions, Android manifest template, and Android toolchain readiness workflow.

## Local validation performed in this work session

- `pytest -q`: **54 passed, 1 skipped**.
- Skipped test: PySide6 runtime imports, because PySide6 is not installed in this isolated build environment.
- `python -m compileall -q src main.py scripts alembic`: passed.
- Android manifest static validation: passed (9 permission declarations).
- Alembic SQLite upgrade: passed.
- Alembic metadata drift check: no new upgrade operations detected.
- FastAPI `/health` smoke test: HTTP 200.

## Not verified / still required

- Ruff was not run: the isolated environment had no Ruff binary and package download was unavailable.
- The PySide6 GUI and camera page were not launched in this environment.
- No physical Linux/Windows camera, GPS, BLE, NFC, or biometric device test was possible.
- The Android native Java/Kotlin/C++ bridge is a defined integration boundary, not a completed implementation.
- Firebase Cloud Messaging token acquisition and server-side push delivery are not implemented.
- PostgreSQL integration/deployment was not run; migration was validated against SQLite.
- Linux/Windows PyInstaller workflows have not been executed in GitHub Actions.
- Android APK/AAB build, signing, installation, and physical-device QA are not complete.
- Production email verification, password reset, refresh-token rotation, rate limiting, billing, audit/observability, PostgreSQL RLS, and security review remain release requirements.

M8 is therefore **development foundation + CI/package scaffolding**, not a production-ready cross-platform release. The remaining items above are release gates and must not be marked complete until tested on the target platforms.
