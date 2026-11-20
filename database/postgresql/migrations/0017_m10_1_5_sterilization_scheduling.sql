-- Miselium M10.1.5 / 0017 Sterilization scheduling, shared capacity and cooling.
-- PostgreSQL 16+. Additive follow-up to migrations 0013-0016.
BEGIN;

-- Explicit, global unit conversions. Identity conversions are implicit (factor 1).
-- Only equal dimensions may be related; callers must never infer conversions.
CREATE TABLE measurement_unit_conversions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    from_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
    to_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
    factor numeric(24,12) NOT NULL CHECK (factor > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (from_unit_id, to_unit_id),
    CHECK (from_unit_id <> to_unit_id)
);

CREATE OR REPLACE FUNCTION guard_measurement_unit_conversion()
RETURNS trigger LANGUAGE plpgsql AS $m1015$
DECLARE
    v_from_dimension varchar(20);
    v_to_dimension varchar(20);
BEGIN
    SELECT dimension INTO v_from_dimension FROM measurement_units WHERE id=NEW.from_unit_id;
    SELECT dimension INTO v_to_dimension FROM measurement_units WHERE id=NEW.to_unit_id;
    IF v_from_dimension IS NULL OR v_to_dimension IS NULL
       OR v_from_dimension <> v_to_dimension THEN
        RAISE EXCEPTION 'Unit conversion requires two units with the same dimension'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1015$;
CREATE TRIGGER measurement_unit_conversion_dimension_guard
    BEFORE INSERT OR UPDATE ON measurement_unit_conversions
    FOR EACH ROW EXECUTE FUNCTION guard_measurement_unit_conversion();

ALTER TABLE sterilization_cycles
    ADD COLUMN capacity_unit_id uuid REFERENCES measurement_units(id) ON DELETE RESTRICT,
    ADD COLUMN planned_capacity numeric(24,8) CHECK (planned_capacity IS NULL OR planned_capacity > 0);

ALTER TABLE sterilization_runs
    ADD COLUMN planned_start_at timestamptz,
    ADD COLUMN planned_end_at timestamptz,
    ADD COLUMN cooling_due_at timestamptz,
    ADD COLUMN cycle_minutes_snapshot integer CHECK (cycle_minutes_snapshot IS NULL OR cycle_minutes_snapshot > 0),
    ADD COLUMN cooling_minutes_snapshot integer CHECK (cooling_minutes_snapshot IS NULL OR cooling_minutes_snapshot >= 0),
    ADD COLUMN capacity_to_cycle_unit_snapshot numeric(24,12)
        CHECK (capacity_to_cycle_unit_snapshot IS NULL OR capacity_to_cycle_unit_snapshot > 0);

ALTER TABLE sterilization_run_batches
    ADD COLUMN quantity_to_capacity_unit_snapshot numeric(24,12)
        CHECK (quantity_to_capacity_unit_snapshot IS NULL OR quantity_to_capacity_unit_snapshot > 0),
    ADD COLUMN capacity_quantity_snapshot numeric(24,8)
        CHECK (capacity_quantity_snapshot IS NULL OR capacity_quantity_snapshot > 0);

CREATE INDEX ix_sterilization_runs_machine_schedule
    ON sterilization_runs(tenant_id,sterilizer_id,planned_start_at,planned_end_at)
    WHERE status IN ('planned','running');

CREATE INDEX ix_sterilization_run_batches_batch
    ON sterilization_run_batches(tenant_id,batch_id);

CREATE TABLE sterilization_cycle_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    cycle_id uuid NOT NULL,
    event_type varchar(40) NOT NULL
        CHECK (event_type IN ('cycle_scheduled','run_started','run_completed','cooling_completed','cycle_cancelled')),
    sterilization_run_id uuid,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (tenant_id,id),
    FOREIGN KEY (tenant_id,cycle_id)
        REFERENCES sterilization_cycles(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,sterilization_run_id)
        REFERENCES sterilization_runs(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_sterilization_cycle_events_history
    ON sterilization_cycle_events(tenant_id,cycle_id,occurred_at,id);

CREATE OR REPLACE FUNCTION reject_sterilization_cycle_event_mutation()
RETURNS trigger LANGUAGE plpgsql AS $m1015$
BEGIN
    RAISE EXCEPTION 'Sterilization cycle events are immutable'
        USING ERRCODE='55000';
END;
$m1015$;
CREATE TRIGGER sterilization_cycle_events_immutable
    BEFORE UPDATE OR DELETE ON sterilization_cycle_events
    FOR EACH ROW EXECUTE FUNCTION reject_sterilization_cycle_event_mutation();

CREATE OR REPLACE FUNCTION guard_sterilization_run_cycle()
RETURNS trigger LANGUAGE plpgsql AS $m1015$
DECLARE
    v_machine_unit uuid;
    v_machine_capacity numeric(24,8);
    v_machine_capacity_unit uuid;
    v_machine_cycle_minutes integer;
    v_machine_cooling_minutes integer;
    v_machine_active boolean;
    v_cycle_unit uuid;
    v_cycle_unit_dimension varchar(20);
    v_machine_unit_dimension varchar(20);
    v_expected_factor numeric(24,12);
BEGIN
    SELECT production_unit_id, capacity, capacity_unit_id,
           cycle_minutes, cooling_minutes, is_active
      INTO v_machine_unit, v_machine_capacity, v_machine_capacity_unit,
           v_machine_cycle_minutes, v_machine_cooling_minutes, v_machine_active
      FROM sterilizers
     WHERE tenant_id=NEW.tenant_id AND id=NEW.sterilizer_id;
    SELECT production_unit_id, capacity_unit_id
      INTO v_cycle_unit, v_cycle_unit
      FROM sterilization_cycles
     WHERE tenant_id=NEW.tenant_id AND id=NEW.cycle_id;

    IF NEW.cycle_id IS NULL OR v_machine_unit IS NULL OR v_cycle_unit IS NULL
       OR v_machine_unit <> v_cycle_unit THEN
        RAISE EXCEPTION 'Sterilization run and cycle must belong to the same production unit'
            USING ERRCODE='23514';
    END IF;
    IF NOT v_machine_active THEN
        RAISE EXCEPTION 'Only an active sterilizer can be scheduled'
            USING ERRCODE='23514';
    END IF;
    IF NEW.planned_start_at IS NULL OR NEW.planned_end_at IS NULL
       OR NEW.planned_end_at <= NEW.planned_start_at
       OR NEW.cycle_minutes_snapshot IS NULL
       OR NEW.cooling_minutes_snapshot IS NULL
       OR NEW.capacity_to_cycle_unit_snapshot IS NULL THEN
        RAISE EXCEPTION 'New sterilization runs require schedule and configuration snapshots'
            USING ERRCODE='23514';
    END IF;
    IF NEW.cycle_minutes_snapshot <> v_machine_cycle_minutes
       OR NEW.cooling_minutes_snapshot <> v_machine_cooling_minutes THEN
        RAISE EXCEPTION 'Sterilization duration snapshots must match machine configuration at scheduling'
            USING ERRCODE='23514';
    END IF;

    SELECT dimension INTO v_cycle_unit_dimension FROM measurement_units
     WHERE id=(SELECT capacity_unit_id FROM sterilization_cycles
                WHERE tenant_id=NEW.tenant_id AND id=NEW.cycle_id);
    SELECT dimension INTO v_machine_unit_dimension FROM measurement_units
     WHERE id=v_machine_capacity_unit;
    IF v_cycle_unit_dimension IS NULL OR v_cycle_unit_dimension <> v_machine_unit_dimension THEN
        RAISE EXCEPTION 'Sterilizer capacity and cycle capacity units must share a dimension'
            USING ERRCODE='23514';
    END IF;
    IF v_machine_capacity_unit = (SELECT capacity_unit_id FROM sterilization_cycles
                                   WHERE tenant_id=NEW.tenant_id AND id=NEW.cycle_id) THEN
        v_expected_factor := 1;
    ELSE
        SELECT factor INTO v_expected_factor FROM measurement_unit_conversions
         WHERE from_unit_id=v_machine_capacity_unit
           AND to_unit_id=(SELECT capacity_unit_id FROM sterilization_cycles
                            WHERE tenant_id=NEW.tenant_id AND id=NEW.cycle_id);
    END IF;
    IF v_expected_factor IS NULL
       OR NEW.capacity_to_cycle_unit_snapshot <> v_expected_factor THEN
        RAISE EXCEPTION 'Sterilizer capacity conversion snapshot is missing or stale'
            USING ERRCODE='23514';
    END IF;
    IF abs(extract(epoch FROM (NEW.planned_end_at-NEW.planned_start_at))
           - NEW.cycle_minutes_snapshot*60) > 1 THEN
        RAISE EXCEPTION 'Planned sterilization duration must match the machine cycle duration'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1015$;

CREATE OR REPLACE FUNCTION guard_sterilization_run_batch_capacity()
RETURNS trigger LANGUAGE plpgsql AS $m1015$
DECLARE
    v_batch_output numeric(24,8);
    v_batch_unit uuid;
    v_run_unit uuid;
    v_cycle_unit uuid;
    v_conversion numeric(24,12);
    v_expected numeric(24,8);
    v_machine_capacity numeric(24,8);
    v_machine_factor numeric(24,12);
    v_cycle_total_capacity numeric(24,8);
    v_cycle_total_allocated numeric(24,8);
    v_run_total_allocated numeric(24,8);
    v_batch_total_allocated numeric(24,8);
BEGIN
    SELECT actual_output_quantity, output_unit_id
      INTO v_batch_output, v_batch_unit
      FROM production_batches
     WHERE tenant_id=NEW.tenant_id AND id=NEW.batch_id;
    SELECT sr.capacity_to_cycle_unit_snapshot, sr.sterilizer_id,
           sc.capacity_unit_id
      INTO v_machine_factor, v_run_unit, v_cycle_unit
      FROM sterilization_runs sr
      JOIN sterilization_cycles sc
        ON sc.tenant_id=sr.tenant_id AND sc.id=sr.cycle_id
     WHERE sr.tenant_id=NEW.tenant_id AND sr.id=NEW.sterilization_run_id;
    IF v_batch_output IS NULL OR v_batch_output <= 0 OR v_batch_unit IS NULL THEN
        RAISE EXCEPTION 'Sterilization allocation requires a batch with posted good output'
            USING ERRCODE='23514';
    END IF;
    IF NEW.quantity_unit_id <> v_batch_unit THEN
        RAISE EXCEPTION 'Sterilization allocation unit must match the batch output unit'
            USING ERRCODE='23514';
    END IF;
    IF NEW.quantity_to_capacity_unit_snapshot IS NULL
       OR NEW.capacity_quantity_snapshot IS NULL
       OR abs(NEW.capacity_quantity_snapshot -
              NEW.allocated_quantity*NEW.quantity_to_capacity_unit_snapshot) > 0.0000001 THEN
        RAISE EXCEPTION 'Sterilization allocation requires a valid capacity conversion snapshot'
            USING ERRCODE='23514';
    END IF;

    IF v_batch_unit = v_cycle_unit THEN
        v_conversion := 1;
    ELSE
        SELECT factor INTO v_conversion FROM measurement_unit_conversions
         WHERE from_unit_id=v_batch_unit AND to_unit_id=v_cycle_unit;
    END IF;
    IF v_conversion IS NULL OR v_conversion <> NEW.quantity_to_capacity_unit_snapshot THEN
        RAISE EXCEPTION 'Batch output conversion snapshot is missing or stale'
            USING ERRCODE='23514';
    END IF;

    SELECT s.capacity, sr.capacity_to_cycle_unit_snapshot
      INTO v_machine_capacity, v_machine_factor
      FROM sterilization_runs sr
      JOIN sterilizers s ON s.tenant_id=sr.tenant_id AND s.id=sr.sterilizer_id
     WHERE sr.tenant_id=NEW.tenant_id AND sr.id=NEW.sterilization_run_id;
    SELECT COALESCE(sum(rb.capacity_quantity_snapshot),0)
      INTO v_run_total_allocated
      FROM sterilization_run_batches rb
     WHERE rb.tenant_id=NEW.tenant_id
       AND rb.sterilization_run_id=NEW.sterilization_run_id
       AND (TG_OP='INSERT' OR rb.batch_id<>OLD.batch_id);
    v_run_total_allocated := v_run_total_allocated + NEW.capacity_quantity_snapshot;
    IF v_run_total_allocated > v_machine_capacity*v_machine_factor THEN
        RAISE EXCEPTION 'Sterilizer run allocation exceeds the machine capacity'
            USING ERRCODE='23514';
    END IF;

    SELECT COALESCE(sum(s.capacity*sr.capacity_to_cycle_unit_snapshot),0)
      INTO v_cycle_total_capacity
      FROM sterilization_runs sr
      JOIN sterilizers s ON s.tenant_id=sr.tenant_id AND s.id=sr.sterilizer_id
     WHERE sr.tenant_id=NEW.tenant_id
       AND sr.cycle_id=(SELECT cycle_id FROM sterilization_runs
                         WHERE tenant_id=NEW.tenant_id AND id=NEW.sterilization_run_id);
    SELECT COALESCE(sum(rb.capacity_quantity_snapshot),0)
      INTO v_cycle_total_allocated
      FROM sterilization_run_batches rb
      JOIN sterilization_runs sr
        ON sr.tenant_id=rb.tenant_id AND sr.id=rb.sterilization_run_id
     WHERE rb.tenant_id=NEW.tenant_id
       AND sr.cycle_id=(SELECT cycle_id FROM sterilization_runs
                         WHERE tenant_id=NEW.tenant_id AND id=NEW.sterilization_run_id)
       AND (TG_OP='INSERT' OR (rb.sterilization_run_id,rb.batch_id) <>
           (OLD.sterilization_run_id,OLD.batch_id));
    v_cycle_total_allocated := v_cycle_total_allocated + NEW.capacity_quantity_snapshot;
    IF v_cycle_total_allocated > v_cycle_total_capacity THEN
        RAISE EXCEPTION 'Combined sterilization cycle allocation exceeds participating machine capacity'
            USING ERRCODE='23514';
    END IF;

    SELECT COALESCE(sum(allocated_quantity),0)
      INTO v_batch_total_allocated
      FROM sterilization_run_batches
     WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id
       AND (TG_OP='INSERT' OR (sterilization_run_id,batch_id) <>
           (OLD.sterilization_run_id,OLD.batch_id));
    v_batch_total_allocated := v_batch_total_allocated + NEW.allocated_quantity;
    IF v_batch_total_allocated > v_batch_output THEN
        RAISE EXCEPTION 'Sterilization allocation exceeds the batch good output'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1015$;

CREATE TRIGGER sterilization_run_batch_capacity_guard
    BEFORE INSERT OR UPDATE ON sterilization_run_batches
    FOR EACH ROW EXECUTE FUNCTION guard_sterilization_run_batch_capacity();

CREATE OR REPLACE FUNCTION guard_sterilization_run_schedule_overlap()
RETURNS trigger LANGUAGE plpgsql AS $m1015$
BEGIN
    IF EXISTS (
        SELECT 1 FROM sterilization_runs other
         WHERE other.tenant_id=NEW.tenant_id
           AND other.sterilizer_id=NEW.sterilizer_id
           AND other.id<>NEW.id
           AND other.status IN ('planned','running')
           AND NEW.planned_start_at < other.planned_end_at
           AND other.planned_start_at < NEW.planned_end_at
    ) THEN
        RAISE EXCEPTION 'Sterilizer already has an overlapping scheduled run'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1015$;
CREATE TRIGGER sterilization_run_schedule_overlap_guard
    BEFORE INSERT OR UPDATE OF planned_start_at,planned_end_at,status,sterilizer_id
    ON sterilization_runs
    FOR EACH ROW EXECUTE FUNCTION guard_sterilization_run_schedule_overlap();

CREATE OR REPLACE FUNCTION reject_sterilization_configuration_mutation()
RETURNS trigger LANGUAGE plpgsql AS $m1015$
BEGIN
    RAISE EXCEPTION 'Sterilization cycle/run allocations are immutable after execution; use explicit corrective events'
        USING ERRCODE='55000';
END;
$m1015$;
CREATE TRIGGER sterilization_run_batches_immutable
    BEFORE UPDATE OR DELETE ON sterilization_run_batches
    FOR EACH ROW EXECUTE FUNCTION reject_sterilization_configuration_mutation();

ALTER TABLE measurement_unit_conversions ENABLE ROW LEVEL SECURITY;
ALTER TABLE measurement_unit_conversions FORCE ROW LEVEL SECURITY;
CREATE POLICY measurement_unit_conversions_read ON measurement_unit_conversions
    FOR SELECT USING (true);

ALTER TABLE sterilization_cycle_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE sterilization_cycle_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON sterilization_cycle_events
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());

GRANT SELECT ON measurement_unit_conversions TO miselium_app;
GRANT SELECT, INSERT, UPDATE ON sterilization_cycles TO miselium_app;
GRANT SELECT, INSERT, UPDATE ON sterilization_runs TO miselium_app;
GRANT SELECT, INSERT ON sterilization_run_batches TO miselium_app;
GRANT SELECT, INSERT ON sterilization_cycle_events TO miselium_app;
GRANT SELECT ON sterilizers, production_units, production_batches TO miselium_app;
GRANT SELECT ON measurement_units TO miselium_app;
GRANT INSERT ON tenant_audit_events TO miselium_app;

COMMIT;
