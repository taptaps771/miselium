# M7 — Miselium SaaS backend

## Stack and local run

- FastAPI, SQLAlchemy 2, Alembic, PostgreSQL via psycopg, PyJWT, and Pydantic validation.
- SQLite is supported for isolated tests and local API smoke tests only.
- The backend is a separate process from the PySide6 desktop/mobile client.

```bash
python -m pip install -r requirements/server.txt
export MISELIUM_DATABASE_URL='postgresql+psycopg://miselium:password@localhost:5432/miselium'
export MISELIUM_JWT_SECRET="$(python -c 'import secrets; print(secrets.token_urlsafe(48))')"
alembic upgrade head
uvicorn app.backend.main:app --app-dir src --host 127.0.0.1 --port 8000
```

For local development only, omit `MISELIUM_DATABASE_URL` to use `./miselium-dev.db`. Set `MISELIUM_ENVIRONMENT=development` to enable interactive API docs. Production must use PostgreSQL, a managed secret, HTTPS, and migrations as a deployment step.

## API surface

- `GET /health`
- `POST /v1/auth/register` — create user + workspace + owner membership.
- `POST /v1/auth/login` — authenticate against a selected workspace slug.
- `GET /v1/me` and `GET /v1/tenants` — identity and available workspaces.
- `POST /v1/invitations` and `POST /v1/invitations/accept` — administrator invitation and one-time acceptance.
- `GET/POST /v1/records` and `GET /v1/records/{id}` — example tenant-owned resource demonstrating enforced scoping.
- `GET /v1/usage` — plan usage/limit view.
- `POST /v1/devices` — tenant-scoped device/push-token registration.

## Tenant isolation rules

1. A user identity is global; a user may have multiple `Membership` rows.
2. The active tenant is selected at login and placed in a signed JWT claim. Every authenticated request re-loads the user, tenant, and membership from the database; the JWT role claim is not trusted for authorization.
3. Tenant-owned tables must include a non-null `tenant_id`, indexed and linked to `tenants.id`.
4. Every tenant-owned SELECT, UPDATE, and DELETE must filter by the authenticated tenant ID. Return 404 for another tenant's resource to avoid disclosing its existence.
5. Do not accept tenant IDs from arbitrary request bodies as authorization context.
6. Add cross-tenant negative tests for every new tenant-owned endpoint.

The current sample backend enforces explicit tenant scoping in SQLAlchemy queries and tests it. PostgreSQL Row-Level Security is not enabled in this milestone; adding it requires a carefully managed per-transaction tenant context and separate integration tests. Do not claim database-level RLS protection until that work is completed.

## Security and production readiness

- Passwords are stored as salted scrypt hashes; access tokens are short-lived HS256 JWTs.
- `MISELIUM_JWT_SECRET` must be at least 32 characters and must be stored outside source control.
- Add refresh-token rotation/revocation, email verification, password reset, login throttling/rate limiting, audit events, observability, backup/restore, and a production mail provider before public SaaS launch.
- Invitation creation returns a one-time token only in development. Production returns `delivery_pending`; a transactional email/outbox provider must deliver it before enabling production invitations.
- Device push tokens are sensitive routing identifiers. Restrict database access, use encrypted storage/backup, and implement token rotation/deletion policies.
- Billing provider integration and subscription lifecycle/webhooks are not implemented. The `plan` field and quota checks are an initial entitlement foundation, not a payment system.
