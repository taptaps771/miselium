# Miselium M10 — Production & Inventory Foundation

Prerequisite: M9 `0001_platform_foundation.sql`. Target PostgreSQL 16+.

## Scope

M10 establishes tenant-owned inventory and production: item/category/unit masters, unit conversions, lots, inventory documents and append-only stock ledger, recipes and immutable versions, production batches/events, sterilization, inoculation, incubation, output lots, kumbung placements, losses/recovery, and material-cost snapshots. Purchasing/sales, payments, full overhead/depreciation, HR and IoT telemetry remain later modules.

## Inventory contract

- `measurement_units` is a controlled global unit catalog. Item categories, items, conversions, lots and stock belong to a tenant.
- Every item has a base unit. Unit conversions are explicit positive factors; never infer conversion from labels.
- `inventory_documents` and lines are drafts until posted. Posting is a single service transaction: validate permissions, tenant, unit conversions, lot requirements, source stock, negative-stock policy and idempotency; write ledger movements; mark the document posted.
- `inventory_ledger_entries` is the stock source of truth. It stores signed base quantity and signed value per warehouse/lot. Balance views are projections, not mutable stock columns.
- A transfer creates equal/opposite source and destination entries. Lock stock rows or use serializable transaction semantics to prevent concurrent overselling.
- Posted documents and their lines are immutable. Database triggers reject line insertion/update/deletion after posting; ledger inserts require a posted parent document and a matching document line, and ledger update/deletion is rejected. Correct through reversal/correction documents, never by editing history.
- Default policy rejects negative stock. Lot-tracked items require a lot on every relevant movement.
- Valuation uses a service-owned, explicitly versioned policy (initially moving weighted average by tenant/item/warehouse, with lot traceability). Store NUMERIC values and currency snapshots; never recalculate old values from current prices.

## Production contract

- Recipes are reusable headers; each recipe version is a distinct, immutable formula once used by a batch.
- A batch pins one recipe version, location and production unit. Its lifecycle is validated by domain services and audited in `production_batch_events`; clients cannot freely set statuses.
- Sterilizer capacity and cycle/cooling durations are configurable. A run can combine multiple batches; service validation sums allocations in the sterilizer's capacity unit under transaction locks.
- Inoculation records variety allocations and optional seed-lot traceability.
- Incubation duration is configurable per record. Do not hardcode 30 days.
- Production lots connect outputs to batches and varieties. Kumbung placement is a signed event ledger; capacity and available quantities are checked transactionally.
- Every production loss records stage, reason, quantity and disposition. Recovery creates a new traceable lot and cost record; it never silently restores the source lot.
- Material cost comes from actual posted consumption entries. Finalized production cost snapshots freeze material cost, overhead (zero until later allocation), total, output quantity, unit cost and currency. Later overhead is a separate adjustment/allocation, not a rewrite.

## Tenant isolation and authorization

All M10 operational tables carry `tenant_id`, composite unique keys `(tenant_id,id)`, tenant-aware composite foreign keys and forced RLS. The API derives tenant context from authenticated membership/permissions and sets `app.tenant_id` transaction-locally. Runtime roles must not own tables, be superusers or have BYPASSRLS. Background jobs set tenant context explicitly; pooled connections must not leak it. RLS is defense in depth, not a replacement for service authorization.

## Important invariants

1. No stock mutation outside a posted document and ledger entries.
2. Posting is atomic and idempotent.
3. Transfers are balanced.
4. No negative stock by default.
5. Base quantity and conversion-factor snapshots are persisted.
6. Production consumption links to a posted inventory issue and is recorded once.
7. Sterilizer and kumbung capacity checks are concurrency-safe.
8. Recipe versions and posted historical costs never change.
9. Loss and recovery remain separately traceable.
10. No cross-tenant parent references are possible.

## Legacy SQLite mapping direction

The legacy `db.sql` is a SQLite discovery/migration source, not a PostgreSQL migration. Map `produksi_material` to inventory items; `produksi_materialmovement` to stock documents/ledger; `produksi_lot`, `produksi_lotmaterial`, `produksi_lotmovement` to batch/lot/consumption history; recipe tables to versioned recipes; sterilization/inoculation/incubation tables to the corresponding process records; and variety to tenant varieties. Harvest, overhead and cost adjustment records require separate reconciliation. Preserve source IDs in a migration mapping table. Keep the source untouched, reconcile quantities and historical costs, and never regenerate historic costs from current master prices.

## Exit criteria

- [x] Inventory master, units and conversion model.
- [x] Stock documents, append-only ledger and balance projections.
- [x] Tenant-aware warehouse/lot references and RLS.
- [x] Recipe/version, batch, sterilization, inoculation and incubation schema.
- [x] Production lots, kumbung placement, losses and recovery.
- [x] Historical material and production cost snapshot contract.
- [x] PostgreSQL smoke-test script authored.
- [ ] Apply migration and run tests on PostgreSQL 16+ using a non-owner runtime role. (The expanded smoke test is authored; it still needs an actual run.)
- [ ] Implement posting, stock locking, lifecycle transitions and capacity validation in application services.
- [ ] Complete row-level legacy mapping and stock/cost reconciliation before import.

The last three items require a running PostgreSQL/application environment; a schema commit does not prove runtime behavior.

## Apply

Run M9 first, then:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/postgresql/migrations/0002_production_inventory.sql
```

Run the smoke test on a disposable database as an administrator with a pre-created non-owner, non-superuser `miselium_app` role:

```sql
CREATE ROLE miselium_app NOLOGIN;
GRANT USAGE ON SCHEMA public TO miselium_app;
GRANT SELECT, INSERT ON inventory_items TO miselium_app;
```

Then execute:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/postgresql/tests/0002_production_inventory_smoke.sql
```

The smoke test checks draft-ledger rejection, posting, posted-line immutability, append-only ledger behavior, tenant-scoped reads and cross-tenant write rejection. Do not test RLS as a superuser, table owner or BYPASSRLS role. The script rolls back its fixtures.
