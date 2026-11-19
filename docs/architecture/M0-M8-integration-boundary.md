# M0–M8 Cross-platform Foundation — Integration Boundary

## Source preservation

The M0–M8 client and service foundation is preserved under
`clients/cross-platform/`. It includes the PySide6/QML application, hardware
abstraction contracts and adapters, FastAPI prototype, tests, documentation,
packaging scripts, and CI workflows.

This is an additive source-preservation commit. It does not replace the M9/M10
PostgreSQL platform schema or claim that M0–M8 has been reconciled with it.

## Important database boundary

The M7 prototype in this archive defines its own SQLAlchemy `users`, `tenants`,
`memberships`, `tenant_records`, and related tables, plus an Alembic migration
whose revision starts a separate migration history. M9/M10 define the current
platform identity and tenant foundation in the root `database/postgresql/`
migration chain.

Therefore:

- Do not run `clients/cross-platform/alembic upgrade head` against the
  canonical Miselium database.
- Do not copy the M7 migration into the root PostgreSQL migration chain.
- Treat the M7 backend as a preserved prototype until its authentication,
  membership, tenant context, authorization, and device-registration services
  are adapted to M9 global users and tenant memberships.
- The M9/M10 PostgreSQL schema remains authoritative for the canonical
  platform database.
- Preserve historical data; do not reset or delete existing databases as part
  of this integration.

## Follow-up integration work

1. Map M7 API identity and membership operations to M9 `users`,
   `user_auth_identities`, `tenant_memberships`, tenant RBAC, and location scopes.
2. Replace prototype tenant selection with server-derived authenticated
   membership context and transaction-local `app.tenant_id`.
3. Map device registration to the canonical tenant/device model when that
   domain is implemented.
4. Reconcile API schemas and authorization tests with M9/M10 invariants.
5. Only then promote the adapted backend into the canonical application layout
   and add PostgreSQL integration tests.

## Validation status

This commit preserves source; it is not a claim that the full application,
native Android bridges, physical hardware, or PostgreSQL integration has been
validated. Refer to `clients/cross-platform/docs/MILESTONE-STATUS.md` for the
archive's recorded M0–M8 validation and outstanding release gates.
