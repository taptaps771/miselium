# M7 → M9 Backend Adaptation Contract

Status: architecture contract plus additive RBAC migration; runtime adapter remains incomplete.
Target: canonical PostgreSQL 16+ schema in `database/postgresql/migrations/`.
Preserved prototype: `clients/cross-platform/src/app/backend/`.

## 1. Safety boundary

The current M7 FastAPI backend is a prototype. Its SQLAlchemy metadata and Alembic revision define a second, incompatible identity and tenant schema. Do not run `clients/cross-platform/alembic upgrade head` against the canonical Miselium database, and do not call `Base.metadata.create_all()` against that database.

The canonical schema remains authoritative:
- M9: `database/postgresql/migrations/0001_platform_foundation.sql`
- M10: `database/postgresql/migrations/0002_production_inventory.sql`
- M9 RBAC/invitation compatibility: `database/postgresql/migrations/0003_tenant_rbac_invitation_roles.sql`
- M9 authenticated membership discovery: `database/postgresql/migrations/0004_authenticated_membership_discovery.sql`
- M9 global registration and tenant lifecycle: `database/postgresql/migrations/0005_global_registration_tenant_lifecycle.sql`
- Restricted runtime-role authentication grants: `database/postgresql/roles/0001_miselium_app_auth_read.sql`

The existing M7 backend remains isolated until the adapter and PostgreSQL integration tests are implemented. No existing database or data is to be reset or deleted.

## 2. Model mapping

| M7 prototype | Canonical M9 representation | Adaptation rule |
|---|---|---|
| `users.id` | `users.id` | Preserve UUID identity; global, not tenant-owned. |
| `users.email` | `user_contact_points` | Store normalized email as a contact point. Login must require verified email and handle ambiguous matches safely; do not merge accounts by email. |
| `users.password_hash` | `user_auth_identities.password_hash` | Use provider `password`; credentials belong to the global identity. |
| `users.display_name` | `user_profiles.display_name` | Profile is global. |
| `users.is_active` | `users.status` | Map to explicit account lifecycle states; fail closed for suspended/closed accounts. |
| `tenants.slug` | `tenants.code` | Normalize and preserve a stable tenant code. |
| `tenants.name` | `tenants.name` | Preserve tenant display name. |
| `tenants.plan` | `tenant_subscriptions` + `plans` | Never store plan as a tenant string. Subscription lifecycle is platform-controlled. |
| `tenants.is_active` | `tenants.status` | Use pending/active/suspended/closed. Only Platform Admin approval activates a tenant. |
| `memberships` | `tenant_memberships` | Membership status is explicit and tenant-scoped. |
| `memberships.role` | `tenant_roles`, `tenant_role_permissions`, `membership_role_assignments` | Resolve effective permissions from role assignments; never trust a role string in a token. |
| `tenant_invitations` | `tenant_invitations` | Use normalized email, hashed token, status, expiry, inviter, and accepted user. Role assignment requires a tenant-scoped role reference. |
| `tenant_records` | No canonical domain table | Keep only as prototype/demo; do not migrate to production. |
| `device_registrations` | No canonical device table yet | Defer until a canonical device-registration migration and ownership contract exist. |

## 3. Authentication and tenant selection

The initial service boundary is implemented in `src/app/backend/services/authentication.py`, and the standalone canonical API factory is `src/app/backend/m9_api.py` (run with `uvicorn app.backend.m9_api:create_m9_app --factory` and an explicit PostgreSQL `MISELIUM_DATABASE_URL`). It does not import the M7 ORM models or create the legacy schema.

The API flow is:
1. `POST /v1/auth/login`: verify a global verified-email/password identity and return a short-lived tenant-selection token plus active tenant options; no tenant access token is issued yet.
2. `GET /v1/auth/tenants`: re-list only the authenticated user's active tenant memberships using transaction-local RLS user context.
3. `POST /v1/auth/select-tenant`: re-check account, tenant, and membership state, resolve RBAC permissions, and issue a tenant-scoped access token.
4. `GET /v1/me`: re-authorize the membership and return the current tenant context and effective permissions.

Selection tokens and access tokens use separate JWT audiences and purposes, so a selection token cannot access tenant endpoints. The API commits or rolls back each request transaction before releasing the SQLAlchemy session.

The service boundary includes:
- `authenticate_global_user(...)` verifies one global password identity and returns only that user's active tenant options.
- `authorize_tenant_context(...)` re-checks active account, tenant, and membership state, then resolves permissions from tenant RBAC.

The M9 API is intentionally a separate ASGI factory from the legacy M7 API. It requires PostgreSQL and refuses the legacy SQLite fallback. Route tests cover the state transition with a fake repository/session. A separate PostgreSQL integration test now seeds a canonical global identity and exercises login, tenant selection, and `/v1/me` through the restricted `miselium_app` database role. Pooled-connection reuse and rollback isolation remain additional hardening tests.

Migration `0004_authenticated_membership_discovery.sql` adds transaction-local `app.user_id` context and a narrowly scoped RLS SELECT policy that lets a user discover only their own tenant memberships before a tenant has been selected. Membership writes remain restricted to the selected `app.tenant_id`. The API must set `app.user_id` only after global authentication, inside the same transaction, and must never accept it from a client payload.

1. Resolve the submitted normalized email to exactly one verified global contact point. Zero matches means invalid credentials. Multiple matches must fail closed and enter an explicit account-resolution flow; do not guess or merge.
2. Verify the password against the matching `user_auth_identities` row with provider `password`.
3. Authenticate the global `users` account and reject non-active account status.
4. Select a tenant only from active `tenant_memberships` belonging to that user and an active tenant.
5. Re-check membership and tenant status on every request. A JWT tenant claim is a selected context, not proof of authorization.
6. Resolve permissions from `membership_role_assignments` → `tenant_roles` → `tenant_role_permissions` → `tenant_permissions`. Do not authorize from a client-supplied role or stale JWT role claim.
7. Keep global identity endpoints separate from tenant-scoped endpoints. Tenant context is derived from the authenticated membership, never accepted as an untrusted body/query override.

## 4. Tenant creation and activation

- Self-service registration, if enabled, creates a tenant with status `pending`; it must not activate the tenant or provision modules.
- Platform Admin approval changes tenant lifecycle to `active` and is recorded in platform audit.
- Tenant creation must create one primary `locations` row in the same transaction.
- The initial owner receives a tenant membership and a tenant-scoped owner role assignment. This grants tenant administration only; it does not grant platform permissions or module provisioning rights.
- Plan assignment and module provisioning remain platform-controlled through `tenant_subscriptions` and `tenant_modules`.

## 4A. Global registration and tenant lifecycle

Migration `0005_global_registration_tenant_lifecycle.sql` adds one-time hashed email-verification challenges, a global uniqueness rule for verified email addresses, tenant approval metadata, and the `platform.tenants.approve` permission. It is additive and does not reset existing users or tenants. Existing active tenants are grandfathered using their original creation timestamp; no historical Platform Admin approver is fabricated.

The M9 API now exposes:
- `POST /v1/auth/register`: creates a pending global account, password identity, unverified email contact, and hashed one-time verification challenge.
- `POST /v1/auth/verify-email`: consumes a valid challenge, verifies the contact, activates the global account, and returns a short-lived global tenant-selection token.
- `POST /v1/tenants`: creates a pending tenant, primary location, active owner membership, owner role assignment, location scope, and platform audit event in one database transaction.
- `GET /v1/platform/tenants/pending`: lists pending tenant registrations only to a user with `platform.tenants.approve`.
- `POST /v1/platform/tenants/{tenant_id}/approve`: checks the same platform permission, requires an approval reason, activates the tenant, and writes a platform audit event.

A pending tenant cannot be selected for operational access. Only after Platform Admin approval does it appear in the user's active tenant list. The owner role is tenant-scoped and does not grant platform permissions, plan changes, or module provisioning.

The registration endpoint requires an injected `verification_sender(email, raw_token)` callback. The repository does not yet include an SMTP/provider adapter, so registration deliberately returns HTTP 503 when delivery is not configured; it never returns the raw verification token to the client. Production deployment must wire a trusted email delivery implementation before enabling registration.

Runtime database role grants are extended by migration 0005. Apply it only after the restricted `miselium_app` role exists and after migrations 0001–0004. It does not grant superuser or `BYPASSRLS` privileges.

## 5. Invitation adaptation

Migration `0003_tenant_rbac_invitation_roles.sql` adds a required `role_id` to `tenant_invitations` with composite foreign key `(tenant_id, role_id) → tenant_roles(tenant_id, id)`. Existing invitations are conservatively backfilled to the tenant's `member` role. The migration also seeds built-in owner/admin/member roles and a limited tenant permission vocabulary. The tenant-creation service must call `ensure_tenant_default_roles(tenant_id)` inside the same transaction after setting transaction-local tenant context. Existing memberships are backfilled to the least-privileged member role; promotion must be explicit and audited.

Acceptance must:
- lock the invitation row;
- verify token hash, pending status, and expiry;
- require the authenticated user's verified email to match `email_normalized`;
- create or reactivate the correct tenant membership without changing the global identity;
- create the role assignment in the same transaction;
- mark the invitation accepted with `accepted_by`;
- write a tenant audit event.

The invitation role must be validated against the inviter's permission to assign that role. A Tenant Admin must not assign platform roles or grant module entitlements.

## 6. RLS and transaction discipline

For every tenant-scoped request:
- authenticate globally, then authorize an active tenant membership;
- begin a database transaction;
- set `app.tenant_id` using transaction-local `SET LOCAL` (never session-persistent `SET`);
- execute tenant queries with explicit tenant predicates as well as RLS;
- commit or roll back before returning the pooled connection.

The runtime database role must not be a superuser, table owner, or `BYPASSRLS` role. Tests must verify RLS with the actual restricted runtime role, including pooled-connection reuse after both commit and rollback. Global identity queries must be limited to the authenticated account and explicitly permitted identity workflows.

## 7. API transition plan

| Existing M7 endpoint | Target behavior |
|---|---|
| `POST /v1/auth/register` | Global account registration + pending tenant request; no active tenant token before Platform Admin approval. |
| `POST /v1/auth/login` | Global credential verification followed by explicit active-tenant selection. |
| `GET /v1/me` | Global profile plus active tenant membership context; avoid leaking other tenants' data. |
| `GET /v1/tenants` | Only active memberships and active tenants for the authenticated global user. |
| `POST /v1/invitations` | Tenant RBAC permission check; persist a tenant-scoped role reference after the additive migration. |
| `POST /v1/invitations/accept` | Verified-email, token, expiry, membership, role assignment, and audit checks in one transaction. |
| `/v1/records` | Prototype-only; remove from canonical API until a real domain owns the resource. |
| `/v1/devices` | Deferred until canonical device ownership and push-token lifecycle are designed. |

## 8. Required implementation and acceptance tests

Do not mark the adapter complete until all of these pass against PostgreSQL 16+ using the restricted runtime role:

- [x] Additive M9 RBAC/invitation migration authored; PostgreSQL CI job now applies M9, M10, and RBAC migrations in order and runs smoke tests.
- [x] Global user can register once and create a pending tenant with an owner membership; the same global user can retain multiple tenant memberships (PostgreSQL API integration).
- [x] Password authentication uses global auth identity and verified contact points (API unit tests; PostgreSQL runtime integration still pending).
- [ ] Suspended users, suspended memberships, and non-active tenants fail closed.
- [x] Authenticated membership discovery is RLS-scoped to the current global user before tenant selection.
- [x] A user cannot select a tenant without an active membership (API unit test plus PostgreSQL runtime integration).
- [x] Tenant Admin cannot approve tenant registrations through the platform API; approval requires the global `platform.tenants.approve` permission. Module/plan provisioning endpoints remain platform-only and are not exposed by this API.
- [x] Initial owner role assignment uses tenant-scoped composite foreign keys in the canonical schema.
- [ ] Invitation acceptance is one-time, expiry-safe, email-verified, and atomic.
- [x] Self-only membership discovery has a PostgreSQL smoke test; full M9 API RLS coverage for all queries remains pending.
- [ ] Pooled connections do not retain tenant context across requests, commits, or rollbacks.
- [x] Registration and tenant approval use global identity endpoints; tenant-scoped `/v1/me` only returns the selected membership context.
- [ ] No prototype `tenant_records` or `device_registrations` tables are created in the canonical database.

Until then, M7 is preserved source only, not production-ready canonical backend code.
