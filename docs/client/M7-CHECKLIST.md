# M7 Validation Checklist

- [x] FastAPI application factory and health endpoint.
- [x] SQLAlchemy models and Alembic initial migration.
- [x] Global user identity and multiple workspace memberships.
- [x] scrypt password hashing and short-lived signed JWT access tokens.
- [x] Workspace registration, login, listing, and membership invitations.
- [x] Tenant-scoped sample resource endpoints and cross-tenant negative tests.
- [x] Tenant usage/quota foundation and device registration endpoint.
- [ ] PostgreSQL integration suite and production migration rehearsal.
- [ ] Refresh-token rotation/revocation, email verification, password reset, and rate limiting.
- [ ] Production email/outbox, billing provider, audit events, and observability.
- [ ] PostgreSQL RLS (optional hardening) and transaction-scoped tenant context tests.
