-- Miselium M10.1.7 / 0019 Incubation readiness, variety lineage and kumbung capacity.
-- PostgreSQL 16+. Additive after migrations 0001-0018.
BEGIN;

-- Capacity must use an explicit unit. Existing kumbungs remain readable; they
-- must be assigned a measurement unit before accepting new placements.
ALTER TABLE kumbungs
    ADD COLUMN capacity_unit_id uuid REFERENCES measurement_units(id) ON DELETE RESTRICT;
CREATE INDEX ix_kumbungs_capacity_unit
    ON kumbungs(tenant_id, capacity_unit_id);

CREATE TABLE incubation_record_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    incubation_record_id uuid NOT NULL,
    event_type varchar(32) NOT NULL
        CHECK (event_type IN ('incubation_started','incubation_marked_ready','incubation_moved','incubation_cancelled')),
    occurred_at timestamptz NOT NULL DEFAULT now(),
    actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (tenant_id,id),
    FOREIGN KEY (tenant_id,incubation_record_id)
        REFERENCES incubation_records(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_incubation_record_events_history
    ON incubation_record_events(tenant_id,incubation_record_id,occurred_at,id);

-- A segment partitions the already-posted production lot's traceability
-- quantity by completed inoculation allocation. It does not create inventory
-- ledger movements or duplicate the source inventory lot.
CREATE TABLE production_lot_segments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    production_lot_id uuid NOT NULL,
    inoculation_allocation_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    variety_id uuid NOT NULL,
    quantity numeric(24,8) NOT NULL CHECK (quantity > 0),
    unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id,id),
    UNIQUE (tenant_id,inoculation_allocation_id),
    FOREIGN KEY (tenant_id,production_lot_id)
        REFERENCES production_lots(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,batch_id)
        REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,variety_id)
        REFERENCES mushroom_varieties(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,inoculation_allocation_id)
        REFERENCES inoculation_allocations(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_production_lot_segments_lot
    ON production_lot_segments(tenant_id,production_lot_id,variety_id);

ALTER TABLE kumbung_placements
    ADD COLUMN production_lot_segment_id uuid;
ALTER TABLE kumbung_placements
    ADD CONSTRAINT kumbung_placements_segment_fk
    FOREIGN KEY (tenant_id,production_lot_segment_id)
    REFERENCES production_lot_segments(tenant_id,id) ON DELETE RESTRICT;
CREATE INDEX ix_kumbung_placements_segment
    ON kumbung_placements(tenant_id,production_lot_segment_id,occurred_at)
    WHERE production_lot_segment_id IS NOT NULL;

CREATE OR REPLACE FUNCTION guard_production_lot_segment_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1017$
DECLARE
    v_lot_batch uuid;
    v_lot_quantity numeric(24,8);
    v_lot_unit uuid;
    v_allocation_batch uuid;
    v_allocation_variety uuid;
    v_allocation_quantity numeric(24,8);
    v_allocation_unit uuid;
    v_run_status varchar(20);
    v_existing numeric(24,8);
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.tenant_id::text || ':production-lot:' || NEW.production_lot_id::text,0)
    );
    SELECT batch_id,output_quantity,output_unit_id
      INTO v_lot_batch,v_lot_quantity,v_lot_unit
      FROM production_lots
     WHERE tenant_id=NEW.tenant_id AND id=NEW.production_lot_id;
    SELECT a.batch_id,a.variety_id,a.allocated_quantity,a.quantity_unit_id,r.status
      INTO v_allocation_batch,v_allocation_variety,v_allocation_quantity,v_allocation_unit,v_run_status
      FROM inoculation_allocations a
      JOIN inoculation_runs r
        ON r.tenant_id=a.tenant_id AND r.id=a.inoculation_run_id
     WHERE a.tenant_id=NEW.tenant_id AND a.id=NEW.inoculation_allocation_id;
    IF v_lot_batch IS NULL OR v_allocation_batch IS NULL
       OR v_lot_batch <> NEW.batch_id OR v_allocation_batch <> NEW.batch_id
       OR v_allocation_variety <> NEW.variety_id
       OR v_allocation_quantity <> NEW.quantity
       OR v_allocation_unit <> NEW.unit_id OR v_lot_unit <> NEW.unit_id
       OR v_run_status <> 'completed' THEN
        RAISE EXCEPTION 'Lot segment must exactly match a completed inoculation allocation for its source lot'
            USING ERRCODE='23514';
    END IF;
    SELECT COALESCE(sum(quantity),0) INTO v_existing
      FROM production_lot_segments
     WHERE tenant_id=NEW.tenant_id AND production_lot_id=NEW.production_lot_id;
    IF v_existing + NEW.quantity > v_lot_quantity THEN
        RAISE EXCEPTION 'Variety segments exceed the source production lot quantity'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1017$;
CREATE TRIGGER production_lot_segment_insert_guard
    BEFORE INSERT ON production_lot_segments
    FOR EACH ROW EXECUTE FUNCTION guard_production_lot_segment_insert();

CREATE OR REPLACE FUNCTION guard_kumbung_placement_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1017$
DECLARE
    v_segment_batch uuid;
    v_segment_lot uuid;
    v_segment_unit uuid;
    v_segment_quantity numeric(24,8);
    v_kumbung_location uuid;
    v_kumbung_capacity numeric(18,3);
    v_kumbung_capacity_unit uuid;
    v_kumbung_active boolean;
    v_batch_location uuid;
    v_batch_status varchar(30);
    v_conversion numeric(24,12);
    v_segment_balance numeric(24,8);
    v_occupied numeric(24,8);
    v_unconvertible bigint;
BEGIN
    IF NEW.production_lot_segment_id IS NULL THEN
        RAISE EXCEPTION 'New kumbung placements must reference a variety-specific production lot segment'
            USING ERRCODE='23514';
    END IF;
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.tenant_id::text || ':kumbung:' || NEW.kumbung_id::text,0)
    );
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.tenant_id::text || ':lot-segment:' || NEW.production_lot_segment_id::text,0)
    );
    SELECT s.batch_id,s.production_lot_id,s.unit_id,s.quantity,b.location_id,b.status
      INTO v_segment_batch,v_segment_lot,v_segment_unit,v_segment_quantity,v_batch_location,v_batch_status
      FROM production_lot_segments s
      JOIN production_batches b
        ON b.tenant_id=s.tenant_id AND b.id=s.batch_id
     WHERE s.tenant_id=NEW.tenant_id AND s.id=NEW.production_lot_segment_id;
    SELECT location_id,capacity,capacity_unit_id,is_active
      INTO v_kumbung_location,v_kumbung_capacity,v_kumbung_capacity_unit,v_kumbung_active
      FROM kumbungs
     WHERE tenant_id=NEW.tenant_id AND id=NEW.kumbung_id;
    IF v_segment_batch IS NULL OR v_kumbung_location IS NULL
       OR v_kumbung_active IS DISTINCT FROM true
       OR v_batch_location <> v_kumbung_location
       OR v_batch_status <> 'ready' THEN
        RAISE EXCEPTION 'Placement requires a ready batch and an active kumbung at its location'
            USING ERRCODE='23514';
    END IF;
    IF NEW.unit_id <> v_segment_unit OR v_kumbung_capacity_unit IS NULL THEN
        RAISE EXCEPTION 'Placement unit must match the lot segment and kumbung capacity unit must be configured'
            USING ERRCODE='23514';
    END IF;
    IF NEW.movement_type IN ('place','move_in') AND NEW.quantity_delta <= 0
       OR NEW.movement_type IN ('move_out','harvest_remove','loss_remove') AND NEW.quantity_delta >= 0 THEN
        RAISE EXCEPTION 'Placement movement direction does not match its movement type'
            USING ERRCODE='23514';
    END IF;
    IF NEW.movement_type='correction' THEN
        RAISE EXCEPTION 'Corrections require a dedicated approved reconciliation command'
            USING ERRCODE='23514';
    END IF;
    SELECT factor INTO v_conversion
      FROM measurement_unit_conversions
     WHERE from_unit_id=v_segment_unit AND to_unit_id=v_kumbung_capacity_unit;
    IF v_segment_unit = v_kumbung_capacity_unit THEN
        v_conversion := 1;
    ELSIF v_conversion IS NULL THEN
        RAISE EXCEPTION 'No explicit conversion exists between lot and kumbung capacity units'
            USING ERRCODE='23514';
    END IF;
    SELECT v_segment_quantity + COALESCE(sum(quantity_delta),0)
      INTO v_segment_balance
      FROM kumbung_placements
     WHERE tenant_id=NEW.tenant_id AND production_lot_segment_id=NEW.production_lot_segment_id;
    IF v_segment_balance + NEW.quantity_delta < 0 THEN
        RAISE EXCEPTION 'Placement would overdraw the available variety lot segment'
            USING ERRCODE='23514';
    END IF;
    SELECT count(*) INTO v_unconvertible
      FROM kumbung_placements p
     WHERE p.tenant_id=NEW.tenant_id AND p.kumbung_id=NEW.kumbung_id
       AND p.unit_id <> v_kumbung_capacity_unit
       AND NOT EXISTS (
           SELECT 1 FROM measurement_unit_conversions c
            WHERE c.from_unit_id=p.unit_id AND c.to_unit_id=v_kumbung_capacity_unit
       );
    IF v_unconvertible > 0 THEN
        RAISE EXCEPTION 'Existing kumbung occupancy contains a unit without an explicit capacity conversion'
            USING ERRCODE='23514';
    END IF;
    SELECT COALESCE(sum(
               p.quantity_delta * CASE WHEN p.unit_id=v_kumbung_capacity_unit
                                       THEN 1 ELSE c.factor END
           ),0)
      INTO v_occupied
      FROM kumbung_placements p
      LEFT JOIN measurement_unit_conversions c
        ON c.from_unit_id=p.unit_id AND c.to_unit_id=v_kumbung_capacity_unit
     WHERE p.tenant_id=NEW.tenant_id AND p.kumbung_id=NEW.kumbung_id;
    IF v_occupied + (NEW.quantity_delta * v_conversion) > v_kumbung_capacity THEN
        RAISE EXCEPTION 'Placement exceeds remaining kumbung capacity'
            USING ERRCODE='23514';
    END IF;
    IF v_occupied + (NEW.quantity_delta * v_conversion) < 0 THEN
        RAISE EXCEPTION 'Placement movement would make kumbung occupancy negative'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1017$;
CREATE TRIGGER kumbung_placement_capacity_guard
    BEFORE INSERT ON kumbung_placements
    FOR EACH ROW EXECUTE FUNCTION guard_kumbung_placement_insert();

CREATE OR REPLACE FUNCTION reject_m10_1_7_history_mutation()
RETURNS trigger LANGUAGE plpgsql AS $m1017$
BEGIN
    RAISE EXCEPTION 'M10.1.7 lineage and incubation history is immutable'
        USING ERRCODE='55000';
END;
$m1017$;
CREATE TRIGGER production_lot_segments_immutable
    BEFORE UPDATE OR DELETE ON production_lot_segments
    FOR EACH ROW EXECUTE FUNCTION reject_m10_1_7_history_mutation();
CREATE TRIGGER incubation_record_events_immutable
    BEFORE UPDATE OR DELETE ON incubation_record_events
    FOR EACH ROW EXECUTE FUNCTION reject_m10_1_7_history_mutation();

ALTER TABLE incubation_record_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE incubation_record_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON incubation_record_events
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());
ALTER TABLE production_lot_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_lot_segments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON production_lot_segments
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());

GRANT SELECT,INSERT,UPDATE ON incubation_records TO miselium_app;
GRANT SELECT,INSERT ON incubation_record_events TO miselium_app;
GRANT SELECT,INSERT ON production_lot_segments TO miselium_app;
GRANT SELECT,INSERT ON kumbung_placements TO miselium_app;
GRANT SELECT ON kumbungs,production_lots,production_batches,inoculation_allocations,
    inoculation_runs,measurement_unit_conversions,measurement_units TO miselium_app;
GRANT INSERT ON tenant_audit_events TO miselium_app;

COMMIT;
