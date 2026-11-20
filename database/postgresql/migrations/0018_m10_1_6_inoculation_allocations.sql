-- Miselium M10.1.6 / 0018 Inoculation allocations and run history
-- PostgreSQL 16+. Additive migration after 0017.
BEGIN;

CREATE TABLE inoculation_run_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    inoculation_run_id uuid NOT NULL,
    event_type varchar(32) NOT NULL
        CHECK (event_type IN ('inoculation_scheduled','inoculation_completed','inoculation_cancelled')),
    occurred_at timestamptz NOT NULL DEFAULT now(),
    actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (tenant_id,id),
    FOREIGN KEY (tenant_id,inoculation_run_id)
        REFERENCES inoculation_runs(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_inoculation_run_events_history
    ON inoculation_run_events(tenant_id,inoculation_run_id,occurred_at,id);

CREATE OR REPLACE FUNCTION reject_inoculation_record_mutation()
RETURNS trigger LANGUAGE plpgsql AS $m1016$
BEGIN
    RAISE EXCEPTION 'Inoculation allocations and events are immutable'
        USING ERRCODE='55000';
END;
$m1016$;

CREATE TRIGGER inoculation_allocations_immutable
    BEFORE UPDATE OR DELETE ON inoculation_allocations
    FOR EACH ROW EXECUTE FUNCTION reject_inoculation_record_mutation();
CREATE TRIGGER inoculation_run_events_immutable
    BEFORE UPDATE OR DELETE ON inoculation_run_events
    FOR EACH ROW EXECUTE FUNCTION reject_inoculation_record_mutation();

CREATE OR REPLACE FUNCTION guard_inoculation_allocation()
RETURNS trigger LANGUAGE plpgsql AS $m1016$
DECLARE
    v_batch_status varchar(30);
    v_batch_unit uuid;
    v_batch_unit_id uuid;
    v_batch_production_unit uuid;
    v_run_production_unit uuid;
    v_run_status varchar(20);
    v_variety_active boolean;
    v_sterilized_quantity numeric(24,8);
    v_existing_allocated numeric(24,8);
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.tenant_id::text || ':production-batch:' || NEW.batch_id::text, 0)
    );

    SELECT status, output_unit_id, production_unit_id
      INTO v_batch_status, v_batch_unit_id, v_batch_production_unit
      FROM production_batches
     WHERE tenant_id=NEW.tenant_id AND id=NEW.batch_id;
    SELECT production_unit_id, status
      INTO v_run_production_unit, v_run_status
      FROM inoculation_runs
     WHERE tenant_id=NEW.tenant_id AND id=NEW.inoculation_run_id
     FOR UPDATE;
    SELECT is_active INTO v_variety_active
      FROM mushroom_varieties
     WHERE tenant_id=NEW.tenant_id AND id=NEW.variety_id;

    IF v_batch_status <> 'inoculation' OR v_run_status <> 'planned' THEN
        RAISE EXCEPTION 'Allocation requires an inoculation-stage batch and a planned inoculation run'
            USING ERRCODE='23514';
    END IF;
    IF v_batch_production_unit IS DISTINCT FROM v_run_production_unit THEN
        RAISE EXCEPTION 'Batch and inoculation run must belong to the same production unit'
            USING ERRCODE='23514';
    END IF;
    IF NEW.quantity_unit_id <> v_batch_unit_id THEN
        RAISE EXCEPTION 'Inoculation allocation unit must match batch output unit'
            USING ERRCODE='23514';
    END IF;
    IF v_variety_active IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'Inoculation allocation requires an active mushroom variety'
            USING ERRCODE='23514';
    END IF;

    SELECT COALESCE(sum(rb.allocated_quantity),0)
      INTO v_sterilized_quantity
      FROM sterilization_run_batches rb
      JOIN sterilization_runs sr
        ON sr.tenant_id=rb.tenant_id AND sr.id=rb.sterilization_run_id
      JOIN sterilization_cycles sc
        ON sc.tenant_id=sr.tenant_id AND sc.id=sr.cycle_id
     WHERE rb.tenant_id=NEW.tenant_id AND rb.batch_id=NEW.batch_id
       AND sr.status='completed' AND sc.cooling_completed_at IS NOT NULL
       AND sc.cooling_completed_at <= now();

    IF v_sterilized_quantity <= 0 THEN
        RAISE EXCEPTION 'Inoculation requires completed and cooled sterilization quantity'
            USING ERRCODE='23514';
    END IF;

    SELECT COALESCE(sum(allocated_quantity),0)
      INTO v_existing_allocated
      FROM inoculation_allocations
     WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id;

    IF v_existing_allocated + NEW.allocated_quantity > v_sterilized_quantity THEN
        RAISE EXCEPTION 'Inoculation allocation exceeds the batch quantity released from cooled sterilization'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1016$;

CREATE TRIGGER inoculation_allocation_capacity_guard
    BEFORE INSERT ON inoculation_allocations
    FOR EACH ROW EXECUTE FUNCTION guard_inoculation_allocation();

ALTER TABLE inoculation_run_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE inoculation_run_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON inoculation_run_events
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());

GRANT SELECT, INSERT, UPDATE ON inoculation_runs TO miselium_app;
GRANT SELECT, INSERT ON inoculation_allocations TO miselium_app;
GRANT SELECT, INSERT ON inoculation_run_events TO miselium_app;
GRANT SELECT ON mushroom_varieties, sterilization_run_batches,
    sterilization_runs, sterilization_cycles, production_batches,
    inventory_lots, locations TO miselium_app;
GRANT INSERT, UPDATE ON incubation_records TO miselium_app;
GRANT INSERT ON tenant_audit_events TO miselium_app;

COMMIT;
