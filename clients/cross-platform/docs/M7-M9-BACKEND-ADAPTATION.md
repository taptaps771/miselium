# M7 → M9 Backend Adaptation Contract

Status: architecture and implementation contract; not yet an executable adapter.
Target: canonical PostgreSQL 16+ schema in `database/postgresql/migrations/`.
Preserved prototype: `clients/cross-platform/src/app/backend/`.

## 1. Safety boundary

The current M7 FastAPI backend is a prototype. Its SQLAlchemy metadata and Alembic revision define a second, incompatible identity and tenant schema. Do not run `clients/cross-platform/alembic upgrade head` against the canonical Miselium database, and do not call `Base.metadata.create_all()` against that database.

The canonical schema remains authoritative:
- M9: `database/postgresql/migrations/0001_platform_foundation.sql`
- M10: `database/postgresql/migrations/0002_production_inventory.sql`

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

## 5. Invitation adaptation

M9 `tenant_invitations` currently has no role column, unlike M7. Do not reintroduce an unscoped free-form role string. Before restoring invitation acceptance, add an additive migration that stores a requested role as a tenant-scoped reference, for example nullable `role_id` with composite foreign key `(tenant_id, role_id) → tenant_roles(tenant_id, id)`.

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

- [ ] M9 and M10 migrations apply in order to a clean PostgreSQL database.
- [ ] Global user can have memberships in multiple tenants without duplicate user accounts.
- [ ] Password authentication uses global auth identity and verified contact points.
- [ ] Suspended users, suspended memberships, and non-active tenants fail closed.
- [ ] A user cannot select a tenant without an active membership.
- [ ] Tenant Admin cannot create platform roles, activate modules, or change plans.
- [ ] Role assignment is tenant-safe through composite foreign keys.
- [ ] Invitation acceptance is one-time, expiry-safe, email-verified, and atomic.
- [ ] RLS denies tenant reads/writes when context is absent or belongs to another tenant.
- [ ] Pooled connections do not retain tenant context across requests, commits, or rollbacks.
- [ ] Global identity data is not exposed by tenant-scoped endpoints.
- [ ] No prototype `tenant_records` or `device_registrations` tables are created in the canonical database.

Until then, M7 is preserved source only, not production-ready canonical backend code.
