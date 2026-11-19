-- Miselium M11 / 0003 Modular Settings & Production Machines
-- PostgreSQL 16+. Requires M9 and M10.
-- Settings navigation is catalog-driven; operational records remain normalized.

BEGIN;

CREATE TABLE setting_sections (
    code varchar(40) PRIMARY KEY,
    name varchar(100) NOT NULL,
    description text,
    sort_order integer NOT NULL DEFAULT 100,
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE setting_modules (
    code varchar(60) PRIMARY KEY,
    section_code varchar(40) NOT NULL REFERENCES setting_sections(code) ON DELETE RESTRICT,
    name varchar(120) NOT NULL,
    description text,
    config_version integer NOT NULL DEFAULT 1 CHECK (config_version > 0),
    sort_order integer NOT NULL DEFAULT 100,
    is_available boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tenant_setting_configs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    setting_module_code varchar(60) NOT NULL REFERENCES setting_modules(code) ON DELETE RESTRICT,
    config_version integer NOT NULL CHECK (config_version > 0),
    configuration jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(configuration) = 'object'),
    updated_by uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, setting_module_code),
    UNIQUE (tenant_id, id)
);
CREATE INDEX ix_tenant_setting_configs_module
    ON tenant_setting_configs(tenant_id, setting_module_code);

INSERT INTO setting_sections(code,name,description,sort_order) VALUES
 ('operations','Operasional','Persediaan, produksi, aset, dan fasilitas.',10),
 ('devices','Perangkat','Integrasi perangkat fisik dan otomasi.',20),
 ('interface','Antarmuka','Preferensi tampilan dan pengalaman pengguna.',30);

INSERT INTO setting_modules(code,section_code,name,description,sort_order) VALUES
 ('inventory','operations','Bahan Baku & Persediaan','Master bahan baku, saldo awal, dan impor CSV/Excel.',10),
 ('production_machines','operations','Mesin Produksi','Master mesin, tarif overhead, dan penyusutan aset.',20),
 ('kumbungs','operations','Kumbung','Master kumbung, pemilik, lokasi, dan kapasitas.',30),
 ('production_recipes','operations','Preset Adonan','Formula adonan berversi dengan bahan utama dan estimasi hasil.',40),
 ('fingerprint','devices','Mesin Fingerprint','Koneksi dan sinkronisasi perangkat absensi.',10),
 ('iot','devices','IoT','Perangkat, gateway, sensor, dan otomasi lokal.',20),
 ('appearance','interface','Tampilan','Tema, ukuran huruf, dan preferensi antarmuka.',10);

CREATE TABLE production_machine_types (
    code varchar(40) PRIMARY KEY,
    name varchar(100) NOT NULL,
    default_stage_code varchar(40) NOT NULL,
    description text,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 100
);
INSERT INTO production_machine_types(code,name,default_stage_code,description,sort_order) VALUES
 ('MIXER','Mixer','mixing','Mesin pencampur bahan adonan.',10),
 ('PRESS_BAGLOG','Press Baglog','press_baglog','Mesin pengisian dan pemadatan baglog.',20),
 ('STEAMER','Steamer','sterilization','Mesin sterilisasi berbasis uap.',30),
 ('AUTOCLAVE','Autoclave','sterilization','Autoclave untuk sterilisasi.',40),
 ('SPRAYER_PUMP','Pompa Sprayer','kumbung','Pompa penyemprotan dan pengelolaan kumbung.',50);

CREATE TABLE production_machines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    location_id uuid NOT NULL,
    production_unit_id uuid,
    machine_type_code varchar(40) NOT NULL REFERENCES production_machine_types(code) ON DELETE RESTRICT,
    code varchar(60) NOT NULL,
    name varchar(150) NOT NULL,
    serial_number varchar(120),
    capacity numeric(24,8) CHECK (capacity IS NULL OR capacity > 0),
    capacity_unit_id uuid REFERENCES measurement_units(id) ON DELETE RESTRICT,
    fuel_or_energy_type varchar(40),
    rated_power numeric(16,4) CHECK (rated_power IS NULL OR rated_power > 0),
    rated_power_unit varchar(20),
    purchase_date date,
    in_service_date date,
    acquisition_cost numeric(24,8) NOT NULL DEFAULT 0 CHECK (acquisition_cost >= 0),
    residual_value numeric(24,8) NOT NULL DEFAULT 0 CHECK (residual_value >= 0),
    useful_life_months integer CHECK (useful_life_months IS NULL OR useful_life_months > 0),
    depreciation_method varchar(30) NOT NULL DEFAULT 'straight_line'
        CHECK (depreciation_method IN ('straight_line')),
    depreciation_start_date date,
    status varchar(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','inactive','maintenance','retired')),
    notes text,
    created_by uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id,code),
    UNIQUE (tenant_id,id),
    FOREIGN KEY (tenant_id,location_id) REFERENCES locations(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,production_unit_id) REFERENCES production_units(tenant_id,id) ON DELETE RESTRICT,
    CHECK (residual_value <= acquisition_cost),
    CHECK (in_service_date IS NULL OR purchase_date IS NULL OR in_service_date >= purchase_date),
    CHECK (depreciation_start_date IS NULL OR in_service_date IS NULL OR depreciation_start_date >= in_service_date)
);
CREATE INDEX ix_production_machines_type_status
    ON production_machines(tenant_id,machine_type_code,status);
CREATE INDEX ix_production_machines_location
    ON production_machines(tenant_id,location_id);

CREATE TABLE machine_overhead_rates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    machine_id uuid NOT NULL,
    activity_code varchar(40) NOT NULL,
    calculation_method varchar(40) NOT NULL
        CHECK (calculation_method IN (
            'per_baglog_estimate','per_baglog_actual','per_hour','per_cycle',
            'actual_consumption','manual'
        )),
    rate numeric(24,10) NOT NULL CHECK (rate >= 0),
    currency char(3) NOT NULL DEFAULT 'IDR',
    basis_unit_id uuid REFERENCES measurement_units(id) ON DELETE RESTRICT,
    effective_from date NOT NULL,
    effective_until date,
    notes text,
    created_by uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id,id),
    FOREIGN KEY (tenant_id,machine_id) REFERENCES production_machines(tenant_id,id) ON DELETE RESTRICT,
    CHECK (effective_until IS NULL OR effective_until >= effective_from)
);
CREATE INDEX ix_machine_overhead_rates_effective
    ON machine_overhead_rates(tenant_id,machine_id,activity_code,effective_from DESC);

CREATE TABLE production_machine_cost_allocations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    machine_id uuid NOT NULL,
    overhead_rate_id uuid,
    stage_code varchar(40) NOT NULL
        CHECK (stage_code IN ('mixing','press_baglog','sterilization','kumbung')),
    basis_type varchar(40) NOT NULL
        CHECK (basis_type IN ('estimated_baglog','actual_baglog','duration','cycle','actual_consumption','manual')),
    basis_quantity numeric(24,8) NOT NULL CHECK (basis_quantity >= 0),
    basis_unit_id uuid REFERENCES measurement_units(id) ON DELETE RESTRICT,
    operational_cost numeric(24,8) NOT NULL DEFAULT 0 CHECK (operational_cost >= 0),
    depreciation_cost numeric(24,8) NOT NULL DEFAULT 0 CHECK (depreciation_cost >= 0),
    currency char(3) NOT NULL,
    allocated_at timestamptz NOT NULL DEFAULT now(),
    allocated_by uuid REFERENCES users(id) ON DELETE SET NULL,
    notes text,
    total_cost numeric(24,8) GENERATED ALWAYS AS (operational_cost + depreciation_cost) STORED,
    UNIQUE (tenant_id,id),
    FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,machine_id) REFERENCES production_machines(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,overhead_rate_id) REFERENCES machine_overhead_rates(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_machine_cost_allocations_batch
    ON production_machine_cost_allocations(tenant_id,batch_id,stage_code,allocated_at);

-- A recipe version marks exactly one base ingredient. Its output_quantity is an
-- estimate only; it does not create baglog stock. Actual output is captured at press.
ALTER TABLE recipe_version_items
    ADD COLUMN is_base_ingredient boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX uq_recipe_version_one_base_ingredient
    ON recipe_version_items(tenant_id,recipe_version_id)
    WHERE is_base_ingredient;

-- The production workflow has no separate preparation or cooling stage.
-- Cooling timestamps/conditions are captured as sterilization metadata/events.
ALTER TABLE production_batches
    DROP CONSTRAINT production_batches_status_check;

-- M10 forces RLS on both tables. Temporarily disable it inside this
-- owner-controlled migration so the cross-tenant data migration can preserve
-- every legacy cooling batch; restore ENABLE + FORCE immediately afterwards.
ALTER TABLE production_batches DISABLE ROW LEVEL SECURITY;
ALTER TABLE production_batch_events DISABLE ROW LEVEL SECURITY;

-- Preserve the legacy cooling status as an auditable event, then fold the
-- batch back into the sterilization stage (cooling is no longer a form stage).
INSERT INTO production_batch_events(
    tenant_id,batch_id,event_type,from_status,to_status,occurred_at,notes,metadata
)
SELECT tenant_id,id,'legacy_cooling_status_mapped','cooling','sterilization',now(),
       'Cooling is now represented by sterilization readiness metadata, not a separate lifecycle stage.',
       jsonb_build_object('migration','0003_modular_settings_and_machines')
FROM production_batches
WHERE status='cooling';

UPDATE production_batches
SET status='sterilization', updated_at=now()
WHERE status='cooling';

ALTER TABLE production_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_batches FORCE ROW LEVEL SECURITY;
ALTER TABLE production_batch_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_batch_events FORCE ROW LEVEL SECURITY;

ALTER TABLE production_batches
    ADD CONSTRAINT production_batches_status_check
    CHECK (status IN (
        'draft','planned','mixing','press_baglog','sterilization',
        'inoculation','incubation','ready','on_hold','closed','cancelled'
    ));

-- Cooling is recorded as readiness metadata on the sterilization run, not as
-- an independent production batch status/form.
ALTER TABLE sterilization_runs
    ADD COLUMN cooling_completed_at timestamptz,
    ADD COLUMN cooling_notes text,
    ADD CONSTRAINT sterilization_cooling_completion_check
        CHECK (
            cooling_completed_at IS NULL
            OR (completed_at IS NOT NULL AND cooling_completed_at >= completed_at)
        );

-- Kumbungs already exist in M9 and are referenced by the M10 placement ledger.
-- Keep the location relation and add a tenant-entered owner label for the initial setup UI.
ALTER TABLE kumbungs
    ADD COLUMN owner_name varchar(180);

CREATE OR REPLACE FUNCTION reject_machine_cost_allocation_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Machine cost allocations are immutable; append a correction allocation'
        USING ERRCODE='55000';
END;
$$;
CREATE TRIGGER machine_cost_allocations_immutable
    BEFORE UPDATE OR DELETE ON production_machine_cost_allocations
    FOR EACH ROW EXECUTE FUNCTION reject_machine_cost_allocation_mutation();

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'tenant_setting_configs',
        'production_machines',
        'machine_overhead_rates',
        'production_machine_cost_allocations'
    ] LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY',t);
        EXECUTE format(
            'CREATE POLICY tenant_isolation ON %I USING (tenant_id=current_tenant_id()) WITH CHECK (tenant_id=current_tenant_id())',
            t
        );
    END LOOP;
END $$;

COMMIT;
