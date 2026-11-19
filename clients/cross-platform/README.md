# Miselium — Cross-platform client and SaaS foundation

Miselium is a Python 3.14 + PySide6 6.12.0 + Qt Quick/QML application with a separate FastAPI multi-tenant backend. The architecture targets Linux, Windows, and Android clients while keeping business logic and hardware contracts platform-neutral.

**No Node.js/npm toolchain is required.**

## Milestones

| Milestone | Scope | Source status |
|---|---|---|
| M0 | PySide6/Qt module compatibility PoC | Developer-validated on Linux; Android physical validation remains separate |
| M1 | Configuration, logging, errors, lifecycle, QML app foundation | Included |
| M2 | Hardware abstraction contracts, capability registry, permissions, simulator | Included |
| M3 | Camera preview/capture and QR/barcode image scanning | Included; physical camera and Android decoder validation pending |
| M4 | Location and Bluetooth/BLE capability adapters and safe service fallbacks | Contracts/probes/fallbacks included; physical operations/native async bridge pending |
| M5 | NFC, biometrics, Android file picker and share bridge boundaries | Contracts/protocol/fallbacks included; Android native bridge implementation pending |
| M6 | Local/push notification contracts and tenant-scoped device registration API | Backend registration included; native FCM and delivery provider pending |
| M7 | FastAPI, SQLAlchemy, Alembic, auth, workspaces, membership/invitation, tenant-scoped resources | Initial implementation included; production security/billing/email hardening pending |
| M8 | Linux/Windows CI and desktop package workflow, Android manifest/toolchain readiness | Scaffolding included; signed Android release and physical-device QA pending |

The status distinguishes code implemented in this repository from validation that requires native devices, provider credentials, or a production deployment. Do not treat module imports as proof of hardware support.

## Requirements

- Python `>=3.14,<3.15`
- PySide6 `6.12.0`
- Linux/Windows desktop development: `requirements-dev.txt`
- Backend: `requirements/server.txt`
- Desktop packaging: `requirements/package.txt`
- Optional desktop ZXing decoder: `requirements/scanner.txt`

```bash
python3.14 -m venv .venv
source .venv/bin/activate  # Windows: .venv\\Scripts\\activate
python -m pip install --upgrade pip setuptools wheel
pip install -r requirements-dev.txt -r requirements/server.txt
cp .env.example .env
pytest -q
ruff check .
python main.py
```

Install the optional desktop scanner decoder separately:

```bash
pip install -r requirements/scanner.txt
```

Android must use ABI-compatible native wheels/bridges; do not reuse desktop ZXing wheels.

## Run the SaaS API locally

```bash
export MISELIUM_DATABASE_URL='sqlite:///./miselium-dev.db'
export MISELIUM_JWT_SECRET="$(python -c 'import secrets; print(secrets.token_urlsafe(48))')"
export MISELIUM_ENVIRONMENT=development
alembic upgrade head
uvicorn app.backend.main:app --app-dir src --reload --host 127.0.0.1 --port 8000
```

For PostgreSQL, use `postgresql+psycopg://...` as the database URL. Production deployments must run migrations as a release step, use TLS, a secret manager, rate limiting, backups, monitoring, and a managed PostgreSQL service. See `docs/M7-SAAS-BACKEND.md`.

## Desktop packaging

```bash
pip install -r requirements/package.txt
python scripts/package_desktop.py --clean
```

Build outputs are placed in `dist/`. CI builds Linux and Windows desktop artifacts. Android packaging requires the supported Qt/PySide6 Android toolchain and native bridges; the current Android workflow validates toolchain readiness and manifest declarations but does not sign or publish an APK/AAB.

## Architecture

```text
Qt Quick / QML
      │
      ▼
Qt-facing application controllers and use cases
      ├── Hardware Abstraction Layer (contracts / registry / services)
      ├── API client and synchronization boundary
      └── Core (settings / logging / errors / lifecycle)
                   │ HTTPS
                   ▼
         FastAPI SaaS backend
                   │
          SQLAlchemy / PostgreSQL
                   │
        tenant-scoped data + migrations
```

Hardware contracts do not import PySide6 or native SDKs. Platform adapters translate Qt/native operations into those contracts. Android-only functionality must be implemented in a packaged Java/Kotlin or C++/JNI bridge; Qt's C++ `QJniObject` API is not assumed to be directly callable from Python. The backend is a separate process/deployment target, not embedded in the client.

## Repository layout

```text
src/app/
├── application/       # Qt-facing controllers and use cases
├── backend/           # FastAPI, SQLAlchemy models, auth, API schemas
├── core/              # errors, lifecycle, logging
├── hardware/
│   ├── contracts/     # platform-neutral models and service protocols
│   ├── adapters/      # Qt, optional ZXing, native bridge boundaries, fallbacks
│   ├── services/      # hardware orchestration
│   ├── registry.py    # capability discovery and status registry
│   └── runtime.py     # HAL composition root
└── ui/                # QML presentation
alembic/               # versioned database migrations
platforms/android/     # Android manifest template
scripts/               # environment, hardware, packaging and validation scripts
tests/                 # client/HAL/backend tests
```

## Security baseline

Every tenant-owned table must carry a non-null `tenant_id`; every query must scope by the authenticated membership's tenant. The example resource endpoints are tested against cross-tenant access. PostgreSQL Row-Level Security is not yet enabled. Passwords use scrypt and access tokens use short-lived JWTs; production still requires refresh-token rotation, email verification, throttling, audit/observability, secret management, provider integrations, and security review.

See `docs/ARCHITECTURE.md`, `docs/HARDWARE-API.md`, `docs/PERMISSIONS.md`, `docs/M4-LOCATION-BLE.md`, `docs/M5-ANDROID-BRIDGES.md`, `docs/M6-NOTIFICATIONS.md`, `docs/M7-SAAS-BACKEND.md`, `docs/M8-QA-PACKAGING.md`, and `docs/SECURITY-TENANCY.md`.
