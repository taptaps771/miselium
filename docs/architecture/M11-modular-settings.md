# Miselium M11 — Modular Settings & Production Setup

Status: foundation migration and domain contract  
Database target: PostgreSQL 16+  
Prerequisites: M9 platform foundation and M10 production/inventory foundation

## 1. Goal

The tenant Settings area is an extensible application shell, not one large production setup form. New setting modules (for example fingerprint devices, IoT, and interface preferences) must be addable without restructuring the main Settings navigation.

The database catalog drives the Settings navigation. Tenant-owned operational data remains in dedicated relational tables; the generic settings JSON document is only for versioned module preferences and small configuration values.

## 2. Settings navigation contract

M11 seeds three sections:

| Section | Initial modules |
| --- | --- |
| Operasional | Bahan Baku & Persediaan, Mesin Produksi, Kumbung, Preset Adonan |
| Perangkat | Mesin Fingerprint, IoT |
| Antarmuka | Tema Aplikasi; Preferensi Antarmuka (ukuran huruf, kepadatan, preferensi UI) |

setting_sections and setting_modules are the global catalog. A future module is added by registering a catalog entry and shipping its module implementation. The UI renders only modules available to the platform and allowed for the active tenant. Module availability in this catalog is not a substitute for the existing tenant_modules entitlement system: only Platform Admin provisions commercial application modules.

tenant_setting_configs stores a tenant's versioned, non-secret preferences. Every module validates its own JSON against its own config_version schema in the application service. Unknown keys and unsupported versions must be rejected or migrated explicitly. Do not treat arbitrary JSON as a way to bypass business validation.

### Device security

Fingerprint and IoT connection credentials, API keys, private certificates, and Wi-Fi secrets must never be stored in tenant_setting_configs.configuration. Store secret material in a dedicated encrypted secret store / OS credential vault and persist only a secret reference in tenant configuration. Device control must be permission-checked and audited. Local IoT automation must continue to operate when the cloud connection is unavailable.

## 3. Inventory opening balance and file import

The Inventory Settings module owns the onboarding workflow for initial raw-material data:

1. Download a versioned CSV or Excel template.
2. Fill item code/name/category, base unit, opening quantity, opening unit, conversion factor where applicable, unit cost, currency, warehouse, and optional lot details.
3. Upload and parse the file into a staging preview. Never post directly from a parser.
4. Validate required columns, data types, duplicate item codes, unit mappings, positive conversion factors, warehouse ownership, lot requirements, quantity and monetary precision.
5. Show row-level errors and a summary; allow correction/re-upload.
6. Require an explicit tenant-admin confirmation.
7. Create inventory items where authorized and post one opening-balance inventory document through the existing inventory posting service. Ledger entries remain the stock source of truth.

CSV and XLSX templates must be downloadable from the UI and carry a template version. Import must be idempotent per confirmed import job. Failed validation must not mutate inventory. Existing items must not be silently overwritten; use an explicit match/update policy. Preserve source file name, checksum, actor, timestamp, row counts, and validation report for audit.

## 4. Production machine master

M11 introduces a tenant-owned machine register linked to the existing tenant location and optional production unit.

Initial machine types:

| Code | Label | Default production stage |
| --- | --- | --- |
| MIXER | Mixer | Mixing |
| PRESS_BAGLOG | Press Baglog | Press Baglog |
| STEAMER | Steamer | Sterilization |
| AUTOCLAVE | Autoclave | Sterilization |
| SPRAYER_PUMP | Pompa Sprayer | Kumbung |

Types are global catalog entries; machine instances, capacity, status, acquisition value and costs belong to the tenant. Platform Admin may extend the type catalog later. A machine may be inactive, under maintenance, or retired; historical production allocations remain readable.

### Asset and depreciation inputs

Machine records capture purchase date, in-service date, acquisition cost, residual value, useful life in months, depreciation method, and depreciation start date. M11 initially supports straight-line depreciation:

monthly_depreciation = (acquisition_cost - residual_value) / useful_life_months

The application must prevent depreciation when required asset inputs are incomplete and must not calculate a negative depreciable base. Changes to asset assumptions are effective-dated and must not rewrite posted depreciation or production allocations. Additional depreciation methods can be introduced later as separately versioned policies.

### Operational overhead rates

Rates are machine-specific, not fixed by machine type. Supported calculation methods:

- per_baglog_estimate: mixing overhead uses estimated output from the recipe.
- per_baglog_actual: press overhead uses the actual number processed.
- per_hour: based on recorded machine duration.
- per_cycle: based on machine cycles.
- actual_consumption: measured fuel/energy/consumable use multiplied by a snapshotted price.
- manual: explicitly entered actual cost with actor and reason.

Each rate has currency, optional basis unit, activity code, and effective dates. When a production stage is posted, the system stores a cost allocation snapshot with basis type/quantity, operational cost, depreciation cost, currency, machine, rate reference, actor, and timestamp. A later rate or purchase-price change never changes an old batch.

For the first workflow:
- Mixing: the preset estimates output from the selected base ingredient quantity. That estimate may drive per_baglog_estimate mixing overhead but is not actual baglog output and must not create finished-goods stock.
- Press Baglog: the operator records actual processed baglogs and rejects/losses. per_baglog_actual press overhead uses the configured actual basis (processed quantity, with reject handling explicitly recorded).
- Steamer and Autoclave: use cycle, duration, or actual-consumption rates as configured.
- Pompa Sprayer: costs belong to kumbung/facility operations unless a later approved allocation policy assigns them to production batches.

Cost allocations are append-only. Corrections use compensating allocations, not updates/deletes.

## 5. Kumbung master

M9 already provides tenant-owned kumbungs with a required location, capacity, capacity unit, environment type, and active status. M11 adds an owner label for tenant onboarding.

The UI must expose:
- Kumbung code and name.
- Location (select an existing tenant location).
- Owner name.
- Capacity and capacity unit (default baglog).
- Environment type and active/inactive status.

Capacity is enforced during placement through the M10 placement service and ledger. Do not store a manually editable current occupancy number as the source of truth; calculate occupancy from placements.

## 6. Recipe/preset integration

M10 already provides recipes, immutable recipe versions, recipe version items, and estimated output quantity. M11 marks exactly one recipe-version ingredient as the base ingredient.

The base ingredient is tenant-defined and can use any explicitly configured item unit, such as one sack, one cart, or one kilogram. Conversion to the inventory item's base unit must use a saved positive conversion factor; never infer the weight of a sack/cart from its label.

For a recipe version with base quantity B, requested base ingredient quantity Q, ingredient line quantity I, and estimated output O:

- scale factor = Q / B
- required quantity for ingredient i = I(i) × scale factor
- estimated baglogs = O × scale factor

The recipe version output quantity is an estimate for mixing only. It does not become actual_output_quantity, a production lot, or inventory stock. Actual baglog count is recorded in the Press Baglog stage.

Recipe versions are immutable once used. A changed recipe creates a new version. Batch creation pins the selected recipe version and its unit-conversion snapshots.

## 7. Production lifecycle adjustment

There is no separate Preparation stage and no separate Cooling stage.

- Preparation/setup belongs in Settings and master data.
- Cooling remains a real-world interval, but it is not a separately configurable production form/stage. The sterilizer retains its configured cooling duration; each sterilization run records its completion timestamp and optional cooling_completed_at/cooling_notes fields. The service blocks inoculation until the configured minimum duration has elapsed and cooling completion has been recorded.
- Production stage order is Mixing → Press Baglog → Sterilization → Inoculation → Incubation → Kumbung placement → Reconciliation.
- The Mixing estimate never creates baglog stock. Press records actual quantity and is the first stage that can create actual baglog output, subject to the approved inventory posting contract.

## 8. Security, tenancy, and audit

- All tenant settings and machine data are tenant-scoped and protected by forced RLS.
- The API derives tenant context from authenticated membership and permission checks; never trust a client-supplied tenant ID.
- Setting catalog entries are platform-global. Tenant configuration and machine instances are tenant-owned.
- Do not expose secret material in logs, audit metadata, exports, or settings JSON.
- Posted costs and machine allocations are immutable snapshots.
- Kumbung capacity and stock/placement invariants remain enforced by domain services, not only by the UI.

## 9. Migration and implementation sequence

Migration: database/postgresql/migrations/0012_modular_settings_and_machines.sql.

Recommended implementation sequence:
1. Build the Settings shell from the catalog (sections, module list, permission/entitlement gating).
2. Implement Bahan Baku & Persediaan onboarding, including CSV/XLSX templates, preview, validation, and ledger posting.
3. Implement machine master, effective-dated overhead rates, depreciation calculation and allocation snapshots.
4. Extend Kumbung form with owner and existing location/capacity fields.
5. Add preset base-ingredient selection and proportional scaling.
6. Add fingerprint, IoT and interface modules as independent modules without changing the Settings shell.

The migration and smoke test establish database structure only. They do not claim that the desktop Settings UI, CSV/XLSX parser, machine-cost service, or device integrations are complete.
