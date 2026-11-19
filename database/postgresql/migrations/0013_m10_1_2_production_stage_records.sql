-- Miselium M10.1.2 / 0013 Production stage records
-- PostgreSQL 16+. Requires migrations 0001, 0002, 0011 and 0012.
-- Adds grouped sterilization cycles and immutable press output records.
BEGIN;

CREATE TABLE sterilization_cycles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    production_unit_id uuid NOT NULL,
    cycle_code varchar(70) NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned','running','completed','failed','cancelled')),
    planned_start_at timestamptz,
    started_at timestamptz,
    completed_at timestamptz,
    cooling_completed_at timestamptz,
    operator_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, cycle_code),
    UNIQUE (tenant_id, id),
    FOREIGN KEY (tenant_id, production_unit_id)
        REFERENCES production_units(tenant_id, id) ON DELETE RESTRICT,
    CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at),
    CHECK (cooling_completed_at IS NULL OR
           (completed_at IS NOT NULL AND cooling_completed_at >= completed_at))
);
CREATE INDEX ix_sterilization_cycles_status
    ON sterilization_cycles(tenant_id, status, planned_start_at);

-- Nullable for legacy runs: old records remain valid and are not silently
-- grouped into invented cycles. New application-created runs must supply it.
ALTER TABLE sterilization_runs
    ADD COLUMN cycle_id uuid,
    ADD CONSTRAINT sterilization_runs_cycle_fk
        FOREIGN KEY (tenant_id, cycle_id)
        REFERENCES sterilization_cycles(tenant_id, id) ON DELETE RESTRICT;
CREATE INDEX ix_sterilization_runs_cycle
    ON sterilization_runs(tenant_id, cycle_id)
    WHERE cycle_id IS NOT NULL;
CREATE UNIQUE INDEX uq_sterilization_cycle_machine
    ON sterilization_runs(tenant_id, cycle_id, sterilizer_id)
    WHERE cycle_id IS NOT NULL;

-- One immutable output record per press pass. Multiple passes can be recorded
-- for a batch using sequence_no; quantities are expressed in the same unit.
CREATE TABLE production_press_outputs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    sequence_no integer NOT NULL CHECK (sequence_no > 0),
    machine_id uuid NOT NULL,
    processed_quantity numeric(24,8) NOT NULL CHECK (processed_quantity > 0),
    good_quantity numeric(24,8) NOT NULL CHECK (good_quantity >= 0),
    rejected_quantity numeric(24,8) NOT NULL CHECK (rejected_quantity >= 0),
    quantity_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    recorded_by uuid REFERENCES users(id) ON DELETE SET NULL,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, id),
    UNIQUE (tenant_id, batch_id, sequence_no),
    FOREIGN KEY (tenant_id, batch_id)
        REFERENCES production_batches(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, machine_id)
        REFERENCES production_machines(tenant_id, id) ON DELETE RESTRICT,
    CHECK (processed_quantity = good_quantity + rejected_quantity)
);
CREATE INDEX ix_production_press_outputs_batch
    ON production_press_outputs(tenant_id, batch_id, occurred_at);

-- Press rejects are a first-class production loss stage.
DO $m1012$
DECLARE v_constraint text;
BEGIN
    FOR v_constraint IN
        SELECT conname
          FROM pg_constraint
         WHERE conrelid = 'production_losses'::regclass
           AND contype = 'c'
           AND pg_get_constraintdef(oid) ILIKE '%stage%'
    LOOP
        EXECUTE format('ALTER TABLE production_losses DROP CONSTRAINT %I', v_constraint);
    END LOOP;
END;
$m1012$;
ALTER TABLE production_losses
    ADD CONSTRAINT production_losses_stage_check
    CHECK (stage IN (
        'mixing','press_baglog','sterilization','cooling',
        'inoculation','incubation','kumbung','harvest','other'
    ));

-- New runs must belong to a cycle and the cycle/machine must share a production unit.
-- Existing legacy runs with NULL cycle_id remain readable and untouched.
CREATE OR REPLACE FUNCTION guard_sterilization_run_cycle()
RETURNS trigger LANGUAGE plpgsql AS $m1012$
DECLARE
    v_machine_unit uuid;
    v_cycle_unit uuid;
BEGIN
    IF NEW.cycle_id IS NULL THEN
        RAISE EXCEPTION 'New sterilization runs must belong to a sterilization cycle'
            USING ERRCODE = '23514';
    END IF;
    SELECT production_unit_id INTO v_machine_unit
      FROM sterilizers
     WHERE tenant_id = NEW.tenant_id AND id = NEW.sterilizer_id;
    SELECT production_unit_id INTO v_cycle_unit
      FROM sterilization_cycles
     WHERE tenant_id = NEW.tenant_id AND id = NEW.cycle_id;
    IF v_machine_unit IS NULL OR v_cycle_unit IS NULL OR v_machine_unit <> v_cycle_unit THEN
        RAISE EXCEPTION 'Sterilization cycle and machine must belong to the same production unit'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$m1012$;
CREATE TRIGGER sterilization_run_cycle_guard
    BEFORE INSERT OR UPDATE OF cycle_id, sterilizer_id
    ON sterilization_runs
    FOR EACH ROW EXECUTE FUNCTION guard_sterilization_run_cycle();

-- Press output is accepted only while the batch is in its press stage and
-- only from a tenant-owned machine configured as PRESS_BAGLOG.
CREATE OR REPLACE FUNCTION guard_production_press_output_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1012$
DECLARE
    v_batch_status varchar(30);
    v_machine_type varchar(40);
BEGIN
    SELECT status INTO v_batch_status
      FROM production_batches
     WHERE tenant_id = NEW.tenant_id AND id = NEW.batch_id;
    SELECT machine_type_code INTO v_machine_type
      FROM production_machines
     WHERE tenant_id = NEW.tenant_id AND id = NEW.machine_id;
    IF v_batch_status IS DISTINCT FROM 'press_baglog' THEN
        RAISE EXCEPTION 'Press output can only be recorded for a batch in press_baglog stage'
            USING ERRCODE = '23514';
    END IF;
    IF v_machine_type IS DISTINCT FROM 'PRESS_BAGLOG' THEN
        RAISE EXCEPTION 'Press output requires a PRESS_BAGLOG machine'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$m1012$;
CREATE TRIGGER production_press_output_insert_guard
    BEFORE INSERT ON production_press_outputs
    FOR EACH ROW EXECUTE FUNCTION guard_production_press_output_insert();

CREATE TRIGGER production_press_outputs_immutable
    BEFORE UPDATE OR DELETE ON production_press_outputs
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

ALTER TABLE sterilization_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sterilization_cycles FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON sterilization_cycles
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());

ALTER TABLE production_press_outputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_press_outputs FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON production_press_outputs
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());

GRANT SELECT, INSERT, UPDATE ON sterilization_cycles TO miselium_app;
GRANT SELECT, INSERT, UPDATE ON sterilization_runs TO miselium_app;
GRANT SELECT ON sterilizers TO miselium_app;
GRANT SELECT, INSERT ON production_press_outputs TO miselium_app;
GRANT SELECT ON production_machines, production_units TO miselium_app;
GRANT SELECT, INSERT ON production_losses TO miselium_app;

COMMIT;
