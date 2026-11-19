# Miselium — M9 Platform Foundation

Status: implementation baseline for M9  
Database target: PostgreSQL 16+  
Legacy source: SQLite dump `db.sql` (Shroomery/Django)

## M9 outcome

M9 establishes the platform-level contracts required before implementing production, inventory, purchasing, sales, finance, HR, portals, and IoT modules. It is not a conversion of the legacy SQLite schema into PostgreSQL. The legacy dump is a source for domain discovery and controlled data migration only.

### Decisions locked

1. A Miselium account is global. A user may participate in many tenants.
2. Customer/supplier party identity is global; customer/supplier relationships and all commercial data are tenant-owned.
3. Customer Portal and Supplier Portal are separate experiences, sharing global authentication.
4. Only Platform Admin provisions tenant modules. Tenant Admin cannot enable modules or plans.
5. A tenant is one business. A tenant receives one primary location; additional locations are optional.
6. Locations contain warehouses, production units, and kumbungs.
7. IoT automation at the farm must continue locally when internet connectivity is unavailable.
8. Historical prices and costs are immutable snapshots at posting/consumption time. Master-price changes never rewrite posted documents or historical production costs.
9. Disabling a module preserves its data. Platform support access to tenant business data is separate, time-limited, justified, approved, and audited.
10. No automatic account merge based solely on matching email or phone.

## Delivered artifacts

- `database/postgresql/migrations/0001_platform_foundation.sql`: initial PostgreSQL schema, constraints, indexes, helper functions, and tenant RLS policies.
- `database/postgresql/tests/0001_platform_foundation_smoke.sql`: transactional smoke test for cross-tenant integrity and RLS.
- This document: domain boundaries, migration policy, security contract, and M9 exit criteria.

## Domain model

### Global identity

- `users`: global account and account status.
- `user_profiles`: presentation/profile data.
- `user_auth_identities`: authentication provider identities; credentials are not tenant-specific.
- `user_contact_points`: normalized email/phone, verification and primary flags.
- `global_parties`: person or organization that may transact with multiple businesses.
- `party_user_links`: verified link between a party and a global user account.

An account is not automatically a customer or supplier. The relationship is established independently by each tenant.

### Platform administration and module entitlement

- `platform_roles`, `platform_permissions`, `platform_role_permissions`, `platform_user_roles`: platform-only authorization.
- `platform_audit_events`: audit trail for platform-wide actions.
- `modules`: global module catalog.
- `tenant_modules`: module entitlement/provisioning by Platform Admin.
- `plans`, `plan_modules`, `tenant_subscriptions`: global plan catalog and tenant subscription assignment.

Tenant membership and tenant roles never imply platform permissions. A Tenant Admin cannot write to `tenant_modules`.

### Tenant membership and authorization

- `tenants`: business boundary, default currency and timezone.
- `tenant_memberships`: association between global user and tenant.
- `tenant_invitations`: expiring, hashed invitation tokens.
- `tenant_roles`, `tenant_permissions`, `tenant_role_permissions`, `membership_role_assignments`: tenant RBAC.
- `membership_location_scopes`: optional location-level scope; no row means tenant-wide scope only when the role/service policy explicitly allows it.

The API must derive tenant context from an authenticated membership and authorization decision. Never trust a client-supplied tenant_id by itself.

### Business identity and portals

- `tenant_customers` and `tenant_suppliers` connect a tenant to a global party.
- The same party may be a customer of Tenant A and supplier of Tenant B.
- `customer_portal_access` and `supplier_portal_access` are separate grants.
- Portal grants are tenant-specific and revocable. An account existing does not automatically grant portal access.
- Before granting portal access, the service must verify that the user is linked to the party through a verified `party_user_links` record, or perform an explicitly audited identity-verification workflow.

Commercial terms (credit limit, payment terms, customer/supplier codes, price lists) belong to the tenant relationship, never to the global party.

### Tenant operational structure

```
tenant
  └── location (one primary location on tenant creation)
       ├── warehouse
       ├── production_unit
       └── kumbung
```

A tenant can add locations as it grows. Warehouses, production units, and kumbungs belong to one location and one tenant. Composite foreign keys enforce that parent and child tenant IDs match.

A kumbung has a configurable capacity and unit. Do not hardcode capacity to a fixed baglog count; future capacity models may include shelves/racks and their individual limits.

## Tenant isolation contract

1. Every tenant-owned row carries a non-null `tenant_id`.
2. Every tenant-owned parent referenced by another tenant-owned row is referenced through a composite key `(tenant_id, id)`.
3. Every tenant-owned table is protected by RLS in addition to service-layer authorization.
4. The application sets `app.tenant_id` with `SET LOCAL` inside each transaction after authenticating and authorizing membership.
5. Connection pools must not leak session tenant state. Use transaction-local settings, rollback on errors, and test reuse of pooled connections.
6. Background jobs must establish tenant context explicitly.
7. Platform-global tables are not tenant-filtered, but access is restricted to platform services/roles.
8. RLS is defense in depth, not a replacement for explicit authorization checks.

Example request transaction:

```sql
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-000000000001';
-- tenant-scoped reads/writes
COMMIT;
```

When no tenant context is set, tenant RLS policies return no rows and reject writes.

## Authorization rules

- Platform Admin: manage tenant lifecycle, plans, module provisioning, and platform policies.
- Tenant Owner/Admin: manage their tenant and its users/roles, but cannot provision modules or alter platform plans.
- Tenant roles: least privilege; role assignments are attached to a tenant membership, not directly to a global user.
- Customer Portal: only records whose tenant/customer relationship matches the active portal grant.
- Supplier Portal: only purchasing/supplier records whose tenant/supplier relationship matches the active portal grant.
- Support access: separate support session with actor, tenant, reason, approval, expiry, and audit. No implicit support bypass is included in this schema.

## Price and cost snapshot contract

Price master data is tenant-owned. A future commercial document line must persist, at minimum:

- item code and item name/description snapshot;
- quantity and unit name snapshot;
- unit price and currency;
- discount and tax inputs/amounts;
- subtotal and total;
- price source/list reference and effective date;
- snapshot timestamp and posting actor.

Use PostgreSQL `NUMERIC`, never binary floating point, for monetary and quantity values requiring exact decimal arithmetic. Drafts may be recalculated explicitly. Posted documents are immutable; corrections use reversal/correction documents. Production material and overhead costs are captured at actual consumption/use time and never recomputed using today's master prices.

## SQLite legacy migration policy

The committed `db.sql` is a SQLite dump exported from the prior Shroomery database. It is not a PostgreSQL migration and must never be executed as the target schema.

Migration stages:

1. Keep the original dump immutable and private. Do not use its example users, password hashes, emails, or contact data as production seed data.
2. Create a separate, access-controlled staging copy. Inventory tables, columns, indexes, constraints, row counts, and orphan references.
3. Map legacy `produksi_user` to global users plus tenant memberships; do not carry tenant_id into the global user.
4. Map legacy buyer/supplier rows into global parties only after identity resolution. Do not merge records automatically based only on matching contact fields.
5. Map tenant-scoped locations and operational references with explicit tenant ownership.
6. Preserve posted transaction prices/costs from legacy line snapshots. Do not regenerate them from current master prices.
7. Import in dependency order into PostgreSQL staging, validate row counts and financial/stock reconciliations, then promote through a reviewed migration.
8. Keep source primary keys in a migration mapping table (legacy system, legacy table, legacy ID → new UUID) to preserve traceability.
9. Never reset or delete the source database as part of migration.

The legacy dump contains Django infrastructure tables as well as application tables. Django auth/session/content-type tables are not copied wholesale into the new platform authorization model.

## M9 exit criteria

- [x] Global identity is separated from tenant membership.
- [x] Platform authorization is separated from tenant authorization.
- [x] Module catalog is global and module entitlement is tenant-specific.
- [x] Global party identity is separated from tenant customer/supplier relationships.
- [x] Customer and supplier portal grants are separate and tenant-scoped.
- [x] Tenant/location/warehouse/production-unit/kumbung hierarchy is defined.
- [x] Composite tenant foreign keys and unique constraints are defined.
- [x] Tenant RLS is enabled for tenant-owned foundation tables.
- [x] PostgreSQL smoke tests cover cross-tenant access and referential integrity.
- [x] SQLite-to-PostgreSQL migration policy and price/cost snapshot contract are documented.
- [ ] Execute migrations and integration tests against a provisioned PostgreSQL instance in CI/deployment environment.
- [ ] Complete per-table legacy mapping and reconciliation before importing production data.

The last two items require an actual PostgreSQL service and a controlled migration dataset. They are intentionally not claimed as completed by a schema commit alone.

## Apply locally

Use PostgreSQL 16 or newer. Run from a clean development database:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/postgresql/migrations/0001_platform_foundation.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/postgresql/tests/0001_platform_foundation_smoke.sql
```

The smoke test runs inside a transaction and rolls back its fixtures. Review and adapt role grants to the deployment's database roles before production use.
