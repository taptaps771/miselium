-- Miselium M10.1.8 / 0020 Loss, recovery, reconciliation and costing.
-- PostgreSQL 16+. Additive after migrations 0001-0019.
BEGIN;

ALTER TABLE production_losses
    ADD COLUMN idempotency_key varchar(120),
    ADD COLUMN request_hash char(64),
    ADD COLUMN production_lot_segment_id uuid,
    ADD COLUMN source_kumbung_id uuid,
    ADD CONSTRAINT production_losses_idempotency_key_check
        CHECK (idempotency_key IS NULL OR length(btrim(idempotency_key)) BETWEEN 1 AND 120),
    ADD CONSTRAINT production_losses_request_hash_check
        CHECK (request_hash IS NULL OR request_hash ~ '^[0-9a-f]{64}
        FOREIGN KEY (tenant_id,production_lot_segment_id)
        REFERENCES production_lot_segments(tenant_id,id) ON DELETE RESTRICT,
    ADD CONSTRAINT production_losses_kumbung_fk
        FOREIGN KEY (tenant_id,source_kumbung_id)
        REFERENCES kumbungs(tenant_id,id) ON DELETE RESTRICT,
    ADD CONSTRAINT production_losses_kumbung_source_check
        CHECK (
            (stage='kumbung' AND production_lot_segment_id IS NOT NULL
                              AND source_kumbung_id IS NOT NULL)
            OR
            (stage<>'kumbung' AND production_lot_segment_id IS NULL
                               AND source_kumbung_id IS NULL)
        ) NOT VALID;

CREATE UNIQUE INDEX uq_production_loss_idempotency
    ON production_losses(tenant_id,batch_id,idempotency_key)
    WHERE idempotency_key IS NOT NULL;
CREATE INDEX ix_production_losses_batch_stage
    ON production_losses(tenant_id,batch_id,stage,occurred_at);
CREATE INDEX ix_production_losses_segment
    ON production_losses(tenant_id,production_lot_segment_id,source_kumbung_id)
    WHERE production_lot_segment_id IS NOT NULL;

CREATE TABLE production_loss_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    loss_id uuid NOT NULL,
    event_type varchar(40) NOT NULL
        CHECK (event_type IN ('loss_recorded','loss_disposition_changed','loss_recovery_posted')),
    occurred_at timestamptz NOT NULL DEFAULT now(),
    actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (tenant_id,id),
    FOREIGN KEY (tenant_id,loss_id)
        REFERENCES production_losses(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_production_loss_events_history
    ON production_loss_events(tenant_id,loss_id,occurred_at,id);

ALTER TABLE production_recovery_lots
    ADD COLUMN inventory_document_id uuid,
    ADD COLUMN inventory_document_line_id uuid,
    ADD COLUMN recovered_by uuid REFERENCES users(id) ON DELETE SET NULL,
    ADD COLUMN loss_quantity_snapshot numeric(24,8),
    ADD COLUMN loss_unit_id_snapshot uuid REFERENCES measurement_units(id) ON DELETE RESTRICT,
    ADD COLUMN recovery_mode varchar(24) NOT NULL DEFAULT 'direct_resterilize'
        CHECK (recovery_mode IN ('direct_resterilize','recycle_to_mixing')),
    ADD COLUMN recovered_item_id uuid,
    ADD CONSTRAINT production_recovery_lot_document_fk
        FOREIGN KEY (tenant_id,inventory_document_id)
        REFERENCES inventory_documents(tenant_id,id) ON DELETE RESTRICT,
    ADD CONSTRAINT production_recovery_lot_line_fk
        FOREIGN KEY (tenant_id,inventory_document_line_id)
        REFERENCES inventory_document_lines(tenant_id,id) ON DELETE RESTRICT,
    ADD CONSTRAINT production_recovery_lot_item_fk
        FOREIGN KEY (tenant_id,recovered_item_id)
        REFERENCES inventory_items(tenant_id,id) ON DELETE RESTRICT;
UPDATE production_recovery_lots r
   SET loss_quantity_snapshot=l.quantity,
       loss_unit_id_snapshot=l.unit_id,
       recovered_item_id=il.item_id,
       recovery_mode=CASE
           WHEN il.item_id=source_lot.item_id
            AND r.recovered_quantity=l.quantity AND r.unit_id=l.unit_id
           THEN 'direct_resterilize'
           ELSE 'recycle_to_mixing'
       END
  FROM production_losses l
  JOIN production_lots pl
    ON pl.tenant_id=l.tenant_id AND pl.id=l.production_lot_id
  JOIN inventory_lots source_lot
    ON source_lot.tenant_id=pl.tenant_id AND source_lot.id=pl.inventory_lot_id
  JOIN inventory_lots il ON il.tenant_id=l.tenant_id
 WHERE l.tenant_id=r.tenant_id AND l.id=r.loss_id
   AND il.tenant_id=r.tenant_id AND il.id=r.recovered_inventory_lot_id;
DO $m1018_backfill$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM production_recovery_lots r
          JOIN inventory_items i
            ON i.tenant_id=r.tenant_id AND i.id=r.recovered_item_id
         WHERE r.recovery_mode='recycle_to_mixing'
           AND i.item_type <> 'raw_material'
    ) THEN
        RAISE EXCEPTION 'Legacy partial or cross-item recovery must target a raw-material item before M10.1.8 can be applied';
    END IF;
END;
$m1018_backfill$;
ALTER TABLE production_recovery_lots
    ALTER COLUMN loss_quantity_snapshot SET NOT NULL,
    ALTER COLUMN loss_unit_id_snapshot SET NOT NULL,
    ALTER COLUMN recovered_item_id SET NOT NULL;
CREATE UNIQUE INDEX uq_production_recovery_loss
    ON production_recovery_lots(tenant_id,loss_id);

CREATE TABLE production_batch_reconciliations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    cost_snapshot_id uuid NOT NULL,
    output_quantity numeric(24,8) NOT NULL CHECK (output_quantity > 0),
    placed_quantity numeric(24,8) NOT NULL CHECK (placed_quantity >= 0),
    loss_quantity numeric(24,8) NOT NULL CHECK (loss_quantity >= 0),
    accounted_quantity numeric(24,8) NOT NULL CHECK (accounted_quantity > 0),
    currency char(3) NOT NULL,
    finalized_at timestamptz NOT NULL DEFAULT now(),
    finalized_by uuid REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE (tenant_id,id),
    UNIQUE (tenant_id,batch_id),
    FOREIGN KEY (tenant_id,batch_id)
        REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,cost_snapshot_id)
        REFERENCES production_cost_snapshots(tenant_id,id) ON DELETE RESTRICT,
    CHECK (accounted_quantity = placed_quantity + loss_quantity),
    CHECK (accounted_quantity = output_quantity)
);
CREATE INDEX ix_production_batch_reconciliations_finalized
    ON production_batch_reconciliations(tenant_id,finalized_at DESC);

CREATE OR REPLACE FUNCTION guard_production_loss_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_batch_output numeric(24,8);
    v_batch_output_unit uuid;
    v_lot_batch uuid;
    v_lot_quantity numeric(24,8);
    v_lot_unit uuid;
    v_existing numeric(24,8);
    v_press_rejects numeric(24,8);
    v_press_lot_batch uuid;
    v_segment_batch uuid;
    v_segment_lot uuid;
    v_segment_unit uuid;
    v_kumbung_location uuid;
    v_batch_location uuid;
    v_occupancy numeric(24,8);
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.tenant_id::text || ':production-batch:' || NEW.batch_id::text,0)
    );
    SELECT planned_output_quantity,location_id,output_unit_id
      INTO v_batch_output,v_batch_location,v_batch_output_unit
      FROM production_batches
     WHERE tenant_id=NEW.tenant_id AND id=NEW.batch_id;
    IF v_batch_output IS NULL THEN
        RAISE EXCEPTION 'Loss requires a tenant-owned production batch'
            USING ERRCODE='23503';
    END IF;

    IF NEW.stage='press_baglog' THEN
        SELECT COALESCE(sum(good_quantity*0 + rejected_quantity),0)
          INTO v_press_rejects
          FROM production_press_outputs
         WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id;
        SELECT COALESCE(sum(quantity),0) INTO v_existing
          FROM production_losses
         WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id AND stage='press_baglog';
        IF v_existing + NEW.quantity > v_press_rejects THEN
            RAISE EXCEPTION 'Press rejection loss exceeds immutable rejected press output'
                USING ERRCODE='23514';
        END IF;
        SELECT batch_id,output_unit_id INTO v_press_lot_batch,v_lot_unit
          FROM production_lots
         WHERE tenant_id=NEW.tenant_id AND id=NEW.production_lot_id;
        IF v_press_lot_batch IS DISTINCT FROM NEW.batch_id OR v_lot_unit IS DISTINCT FROM NEW.unit_id THEN
            RAISE EXCEPTION 'Press rejection loss must reference the posted lot from the same batch'
                USING ERRCODE='23514';
        END IF;
    ELSIF NEW.stage='mixing' THEN
        SELECT COALESCE(sum(quantity),0) INTO v_existing
          FROM production_losses
         WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id AND stage='mixing';
        IF NEW.unit_id IS DISTINCT FROM v_batch_output_unit THEN
            RAISE EXCEPTION 'Mixing loss unit must match the batch output unit'
                USING ERRCODE='23514';
        END IF;
        IF v_existing + NEW.quantity > v_batch_output THEN
            RAISE EXCEPTION 'Mixing loss exceeds the batch planned output quantity'
                USING ERRCODE='23514';
        END IF;
        IF NEW.production_lot_id IS NOT NULL THEN
            RAISE EXCEPTION 'Mixing loss must be recorded before a production lot exists'
                USING ERRCODE='23514';
        END IF;
    ELSIF NEW.stage='kumbung' THEN
        PERFORM pg_advisory_xact_lock(
            hashtextextended(NEW.tenant_id::text || ':kumbung:' || NEW.source_kumbung_id::text,0)
        );
        PERFORM pg_advisory_xact_lock(
            hashtextextended(NEW.tenant_id::text || ':lot-segment:' || NEW.production_lot_segment_id::text,0)
        );
        SELECT s.batch_id,s.production_lot_id,s.unit_id,b.location_id
          INTO v_segment_batch,v_segment_lot,v_segment_unit,v_batch_location
          FROM production_lot_segments s
          JOIN production_batches b
            ON b.tenant_id=s.tenant_id AND b.id=s.batch_id
         WHERE s.tenant_id=NEW.tenant_id AND s.id=NEW.production_lot_segment_id;
        SELECT location_id INTO v_kumbung_location
          FROM kumbungs
         WHERE tenant_id=NEW.tenant_id AND id=NEW.source_kumbung_id AND is_active;
        IF v_segment_batch IS DISTINCT FROM NEW.batch_id
           OR v_segment_lot IS DISTINCT FROM NEW.production_lot_id
           OR v_segment_unit IS DISTINCT FROM NEW.unit_id
           OR v_kumbung_location IS DISTINCT FROM v_batch_location THEN
            RAISE EXCEPTION 'Kumbung loss must reference an available segment at the batch location'
                USING ERRCODE='23514';
        END IF;
        SELECT COALESCE(sum(quantity_delta),0) INTO v_occupancy
          FROM kumbung_placements
         WHERE tenant_id=NEW.tenant_id
           AND production_lot_segment_id=NEW.production_lot_segment_id
           AND kumbung_id=NEW.source_kumbung_id;
        SELECT v_occupancy - COALESCE(sum(quantity),0) INTO v_occupancy
          FROM production_losses
         WHERE tenant_id=NEW.tenant_id
           AND production_lot_segment_id=NEW.production_lot_segment_id
           AND source_kumbung_id=NEW.source_kumbung_id
           AND disposition IN ('recovered','recycled','permanent_loss','discarded');
        IF v_occupancy < NEW.quantity THEN
            RAISE EXCEPTION 'Kumbung loss exceeds the quantity currently present in that kumbung'
                USING ERRCODE='23514';
        END IF;
    ELSIF NEW.stage IN ('sterilization','cooling','inoculation','incubation','other') THEN
        SELECT batch_id,output_quantity,output_unit_id
          INTO v_lot_batch,v_lot_quantity,v_lot_unit
          FROM production_lots
         WHERE tenant_id=NEW.tenant_id AND id=NEW.production_lot_id;
        IF v_lot_batch IS DISTINCT FROM NEW.batch_id OR v_lot_unit IS DISTINCT FROM NEW.unit_id THEN
            RAISE EXCEPTION 'Loss must reference a production lot from the same batch and unit'
                USING ERRCODE='23514';
        END IF;
        SELECT COALESCE(sum(quantity),0) INTO v_existing
          FROM production_losses
         WHERE tenant_id=NEW.tenant_id AND production_lot_id=NEW.production_lot_id
           AND stage <> 'press_baglog';
        IF v_existing + NEW.quantity > v_lot_quantity THEN
            RAISE EXCEPTION 'Cumulative production losses exceed the source lot quantity'
                USING ERRCODE='23514';
        END IF;
    ELSE
        RAISE EXCEPTION 'Harvest loss is not enabled until the harvest domain is implemented'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_loss_insert_guard
    BEFORE INSERT ON production_losses
    FOR EACH ROW EXECUTE FUNCTION guard_production_loss_insert();

CREATE OR REPLACE FUNCTION guard_production_loss_mutation()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_recovery_quantity numeric(24,8);
    v_actor uuid;
BEGIN
    IF TG_OP='DELETE' THEN
        RAISE EXCEPTION 'Production loss records are append-only'
            USING ERRCODE='55000';
    END IF;
    IF (to_jsonb(NEW)-'disposition') <> (to_jsonb(OLD)-'disposition')
       OR OLD.disposition <> 'pending'
       OR NEW.disposition NOT IN ('recovered','recycled','permanent_loss','discarded') THEN
        RAISE EXCEPTION 'Only a pending loss may receive one terminal disposition'
            USING ERRCODE='55000';
    END IF;
    IF NEW.disposition IN ('recovered','recycled') THEN
        SELECT COALESCE(sum(loss_quantity_snapshot),0) INTO v_recovery_quantity
          FROM production_recovery_lots
         WHERE tenant_id=NEW.tenant_id AND loss_id=NEW.id;
        IF v_recovery_quantity <> NEW.quantity THEN
            RAISE EXCEPTION 'Recovered or recycled disposition requires a full matching recovery lot'
                USING ERRCODE='23514';
        END IF;
    END IF;
    v_actor := NULLIF(current_setting('app.user_id',true),'')::uuid;
    INSERT INTO production_loss_events(
        tenant_id,loss_id,event_type,actor_user_id,metadata
    ) VALUES (
        NEW.tenant_id,NEW.id,'loss_disposition_changed',v_actor,
        jsonb_build_object('from',OLD.disposition,'to',NEW.disposition)
    );
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_losses_mutation_guard
    BEFORE UPDATE OR DELETE ON production_losses
    FOR EACH ROW EXECUTE FUNCTION guard_production_loss_mutation();

CREATE OR REPLACE FUNCTION record_production_loss_event()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
BEGIN
    INSERT INTO production_loss_events(
        tenant_id,loss_id,event_type,occurred_at,actor_user_id,metadata
    ) VALUES (
        NEW.tenant_id,NEW.id,'loss_recorded',NEW.occurred_at,NEW.recorded_by,
        jsonb_build_object('stage',NEW.stage,'quantity',NEW.quantity,
                           'unit_id',NEW.unit_id,'reason_code',NEW.reason_code)
    );
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_loss_recorded_event
    AFTER INSERT ON production_losses
    FOR EACH ROW EXECUTE FUNCTION record_production_loss_event();

CREATE OR REPLACE FUNCTION guard_production_recovery_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_loss_quantity numeric(24,8);
    v_loss_unit uuid;
    v_loss_recoverable boolean;
    v_loss_disposition varchar(30);
    v_source_item uuid;
    v_recovered_item_type varchar(30);
    v_recovered_item_active boolean;
    v_recovered_lot_item uuid;
    v_document_type varchar(30);
    v_document_status varchar(20);
    v_line_document uuid;
    v_line_lot uuid;
    v_line_quantity numeric(24,8);
    v_line_item uuid;
    v_line_unit uuid;
    v_line_base_quantity numeric(24,8);
    v_line_currency char(3);
    v_ledger_quantity numeric(24,8);
    v_ledger_value numeric(24,8);
    v_ledger_currency char(3);
BEGIN
    SELECT l.quantity,l.unit_id,l.recoverable,l.disposition,src_lot.item_id
      INTO v_loss_quantity,v_loss_unit,v_loss_recoverable,v_loss_disposition,v_source_item
      FROM production_losses l
      LEFT JOIN production_lots pl
        ON pl.tenant_id=l.tenant_id AND pl.id=l.production_lot_id
      LEFT JOIN inventory_lots src_lot
        ON src_lot.tenant_id=pl.tenant_id AND src_lot.id=pl.inventory_lot_id
     WHERE l.tenant_id=NEW.tenant_id AND l.id=NEW.loss_id
     FOR UPDATE OF l;
    IF v_loss_quantity IS NULL OR v_loss_recoverable IS DISTINCT FROM true
       OR v_loss_disposition <> 'pending'
       OR NEW.loss_quantity_snapshot <> v_loss_quantity
       OR NEW.loss_unit_id_snapshot <> v_loss_unit THEN
        RAISE EXCEPTION 'Recovery requires a full, recoverable, pending source loss snapshot'
            USING ERRCODE='23514';
    END IF;
    SELECT item_type,is_active INTO v_recovered_item_type,v_recovered_item_active
      FROM inventory_items
     WHERE tenant_id=NEW.tenant_id AND id=NEW.recovered_item_id;
    SELECT item_id INTO v_recovered_lot_item
      FROM inventory_lots
     WHERE tenant_id=NEW.tenant_id AND id=NEW.recovered_inventory_lot_id;
    IF v_recovered_item_active IS DISTINCT FROM true
       OR v_recovered_lot_item IS DISTINCT FROM NEW.recovered_item_id THEN
        RAISE EXCEPTION 'Recovery inventory lot must use the selected active tenant item'
            USING ERRCODE='23514';
    END IF;
    IF NEW.recovery_mode='direct_resterilize' THEN
        IF NEW.recovered_item_id IS DISTINCT FROM v_source_item
           OR NEW.recovered_quantity <> v_loss_quantity
           OR NEW.unit_id IS DISTINCT FROM v_loss_unit THEN
            RAISE EXCEPTION 'Direct resterilization must preserve the source baglog item, quantity and unit'
                USING ERRCODE='23514';
        END IF;
    ELSIF NEW.recovery_mode='recycle_to_mixing' THEN
        IF v_recovered_item_type <> 'raw_material' THEN
            RAISE EXCEPTION 'Recycling to mixing must create stock for a raw-material inventory item'
                USING ERRCODE='23514';
        END IF;
    ELSE
        RAISE EXCEPTION 'Unsupported production recovery mode'
            USING ERRCODE='23514';
    END IF;

    SELECT document_type,status INTO v_document_type,v_document_status
      FROM inventory_documents
     WHERE tenant_id=NEW.tenant_id AND id=NEW.inventory_document_id;
    SELECT document_id,lot_id,quantity,item_id,unit_id,base_quantity,currency
      INTO v_line_document,v_line_lot,v_line_quantity,v_line_item,v_line_unit,
           v_line_base_quantity,v_line_currency
      FROM inventory_document_lines
     WHERE tenant_id=NEW.tenant_id AND id=NEW.inventory_document_line_id;
    SELECT quantity_delta,value_delta,currency
      INTO v_ledger_quantity,v_ledger_value,v_ledger_currency
      FROM inventory_ledger_entries
     WHERE tenant_id=NEW.tenant_id
       AND document_id=NEW.inventory_document_id
       AND document_line_id=NEW.inventory_document_line_id;
    IF v_document_type IS DISTINCT FROM 'recovery'
       OR v_document_status IS DISTINCT FROM 'posted'
       OR v_line_document IS DISTINCT FROM NEW.inventory_document_id
       OR v_line_lot IS DISTINCT FROM NEW.recovered_inventory_lot_id
       OR v_line_quantity IS DISTINCT FROM NEW.recovered_quantity
       OR v_line_item IS DISTINCT FROM NEW.recovered_item_id
       OR v_line_unit IS DISTINCT FROM NEW.unit_id
       OR v_ledger_quantity IS DISTINCT FROM v_line_base_quantity
       OR v_ledger_currency IS DISTINCT FROM NEW.currency
       OR v_line_currency IS DISTINCT FROM NEW.currency
       OR v_ledger_value IS DISTINCT FROM (NEW.original_cost_snapshot + NEW.recovery_cost_snapshot) THEN
        RAISE EXCEPTION 'Recovery record requires a matching posted recovery document and stock ledger'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_recovery_insert_guard
    BEFORE INSERT ON production_recovery_lots
    FOR EACH ROW EXECUTE FUNCTION guard_production_recovery_insert();
CREATE TRIGGER production_recovery_lots_immutable
    BEFORE UPDATE OR DELETE ON production_recovery_lots
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

CREATE OR REPLACE FUNCTION record_recovery_event()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
BEGIN
    INSERT INTO production_loss_events(
        tenant_id,loss_id,event_type,actor_user_id,metadata
    ) VALUES (
        NEW.tenant_id,NEW.loss_id,'loss_recovery_posted',NEW.recovered_by,
        jsonb_build_object('recovery_lot_id',NEW.id,
                           'loss_quantity',NEW.loss_quantity_snapshot,
                           'recovered_quantity',NEW.recovered_quantity,
                           'recovery_mode',NEW.recovery_mode,
                           'recovered_item_id',NEW.recovered_item_id,
                           'total_recovery_cost',NEW.total_recovery_cost,
                           'currency',NEW.currency)
    );
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_recovery_event
    AFTER INSERT ON production_recovery_lots
    FOR EACH ROW EXECUTE FUNCTION record_recovery_event();

CREATE OR REPLACE FUNCTION guard_production_batch_reconciliation_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_status varchar(30);
    v_output numeric(24,8);
    v_placed numeric(24,8);
    v_losses numeric(24,8);
    v_pending bigint;
    v_missing_recovery bigint;
    v_snapshot_batch uuid;
    v_snapshot_output numeric(24,8);
    v_snapshot_currency char(3);
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.tenant_id::text || ':production-batch:' || NEW.batch_id::text,0)
    );
    SELECT status INTO v_status
      FROM production_batches
     WHERE tenant_id=NEW.tenant_id AND id=NEW.batch_id
     FOR UPDATE;
    SELECT COALESCE(sum(output_quantity),0) INTO v_output
      FROM production_lots
     WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id;
    SELECT COALESCE(sum(p.quantity_delta),0) - COALESCE((
               SELECT sum(l.quantity) FROM production_losses l
                WHERE l.tenant_id=NEW.tenant_id AND l.batch_id=NEW.batch_id
                  AND l.stage='kumbung'
                  AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
           ),0) INTO v_placed
      FROM kumbung_placements p
      JOIN production_lot_segments s
        ON s.tenant_id=p.tenant_id AND s.id=p.production_lot_segment_id
     WHERE p.tenant_id=NEW.tenant_id AND s.batch_id=NEW.batch_id;
    SELECT COALESCE(sum(quantity) FILTER (WHERE stage <> 'mixing'),0),
           count(*) FILTER (WHERE disposition='pending'),
           count(*) FILTER (
               WHERE disposition IN ('recovered','recycled')
                 AND NOT EXISTS (
                     SELECT 1 FROM production_recovery_lots r
                      WHERE r.tenant_id=l.tenant_id AND r.loss_id=l.id
                        AND r.loss_quantity_snapshot=l.quantity
                 )
           )
      INTO v_losses,v_pending,v_missing_recovery
      FROM production_losses l
     WHERE l.tenant_id=NEW.tenant_id AND l.batch_id=NEW.batch_id
       AND l.stage <> 'press_baglog';
    SELECT batch_id,output_quantity,currency
      INTO v_snapshot_batch,v_snapshot_output,v_snapshot_currency
      FROM production_cost_snapshots
     WHERE tenant_id=NEW.tenant_id AND id=NEW.cost_snapshot_id;
    IF v_status IS DISTINCT FROM 'ready'
       OR v_snapshot_batch IS DISTINCT FROM NEW.batch_id
       OR v_snapshot_output IS DISTINCT FROM NEW.output_quantity
       OR v_snapshot_currency IS DISTINCT FROM NEW.currency
       OR v_pending <> 0 OR v_missing_recovery <> 0
       OR v_output <> NEW.output_quantity
       OR v_placed <> NEW.placed_quantity
       OR v_losses <> NEW.loss_quantity
       OR v_placed + v_losses <> v_output
       OR NEW.accounted_quantity <> v_output THEN
        RAISE EXCEPTION 'Batch output, placements, losses, recovery and cost snapshot do not reconcile'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_batch_reconciliation_insert_guard
    BEFORE INSERT ON production_batch_reconciliations
    FOR EACH ROW EXECUTE FUNCTION guard_production_batch_reconciliation_insert();

CREATE TRIGGER production_loss_events_immutable
    BEFORE UPDATE OR DELETE ON production_loss_events
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();
CREATE TRIGGER production_batch_reconciliations_immutable
    BEFORE UPDATE OR DELETE ON production_batch_reconciliations
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

ALTER TABLE production_loss_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_loss_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON production_loss_events
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());
ALTER TABLE production_batch_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_batch_reconciliations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON production_batch_reconciliations
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());

-- Update the occupancy view to account for append-only kumbung loss records.
CREATE OR REPLACE VIEW kumbung_stock WITH (security_invoker=true) AS
SELECT p.tenant_id,p.kumbung_id,p.production_lot_id,p.unit_id,
       sum(p.quantity_delta) - COALESCE((
           SELECT sum(l.quantity)
             FROM production_losses l
            WHERE l.tenant_id=p.tenant_id
              AND l.stage='kumbung'
              AND l.source_kumbung_id=p.kumbung_id
              AND l.production_lot_id=p.production_lot_id
              AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
       ),0) AS quantity_present
  FROM kumbung_placements p
 GROUP BY p.tenant_id,p.kumbung_id,p.production_lot_id,p.unit_id;

GRANT SELECT,INSERT ON production_loss_events TO miselium_app;
GRANT SELECT,UPDATE (disposition) ON production_losses TO miselium_app;
GRANT SELECT,INSERT ON production_recovery_lots TO miselium_app;
GRANT SELECT,INSERT ON production_batch_reconciliations TO miselium_app;
GRANT SELECT,INSERT ON production_cost_snapshots TO miselium_app;
GRANT SELECT ON production_machine_cost_allocations,production_lot_segments,
    kumbung_placements,production_lots,production_press_outputs,
    production_batches,inventory_item_units,inventory_items,measurement_units,
    inventory_stock_by_warehouse TO miselium_app;
GRANT INSERT ON inventory_lots,inventory_documents,inventory_document_lines,
    inventory_ledger_entries,tenant_audit_events TO miselium_app;


CREATE OR REPLACE FUNCTION guard_production_cost_snapshot_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_status varchar(30);
    v_currency char(3);
    v_output numeric(24,8);
    v_material numeric(24,8);
    v_material_count bigint;
    v_material_currencies bigint;
    v_material_currency char(3);
    v_overhead numeric(24,8);
    v_overhead_currencies bigint;
    v_overhead_currency char(3);
BEGIN
    SELECT b.status,t.default_currency
      INTO v_status,v_currency
      FROM production_batches b
      JOIN tenants t ON t.id=b.tenant_id
     WHERE b.tenant_id=NEW.tenant_id AND b.id=NEW.batch_id;
    SELECT COALESCE(sum(output_quantity),0) INTO v_output
      FROM production_lots
     WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id;
    SELECT count(*),COALESCE(sum(material_cost_snapshot),0),
           count(DISTINCT currency),min(currency)
      INTO v_material_count,v_material,v_material_currencies,v_material_currency
      FROM production_batch_consumptions
     WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id;
    SELECT COALESCE(sum(total_cost),0),count(DISTINCT currency),min(currency)
      INTO v_overhead,v_overhead_currencies,v_overhead_currency
      FROM production_machine_cost_allocations
     WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id;
    IF v_status IS DISTINCT FROM 'ready'
       OR NEW.output_quantity <> v_output
       OR v_material_count = 0 OR v_material_currencies <> 1
       OR v_material_currency <> v_currency
       OR NEW.material_cost <> v_material
       OR v_overhead_currencies > 1
       OR (v_overhead_currencies=1 AND v_overhead_currency <> v_currency)
       OR NEW.overhead_cost <> v_overhead
       OR NEW.currency <> v_currency THEN
        RAISE EXCEPTION 'Cost snapshot must match posted batch consumption, machine overhead and tenant currency'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_cost_snapshot_insert_guard
    BEFORE INSERT ON production_cost_snapshots
    FOR EACH ROW EXECUTE FUNCTION guard_production_cost_snapshot_insert();

-- Keep placement capacity and available-segment checks consistent with loss records.
CREATE OR REPLACE FUNCTION guard_kumbung_placement_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1017$
DECLARE
    v_segment_batch uuid;
    v_lock_batch uuid;
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
    v_source_occupancy numeric(24,8);
    v_occupied numeric(24,8);
    v_unconvertible bigint;
BEGIN
    IF NEW.production_lot_segment_id IS NULL THEN
        RAISE EXCEPTION 'New kumbung placements must reference a variety-specific production lot segment'
            USING ERRCODE='23514';
    END IF;
    SELECT batch_id INTO v_lock_batch
      FROM production_lot_segments
     WHERE tenant_id=NEW.tenant_id AND id=NEW.production_lot_segment_id;
    IF v_lock_batch IS NULL THEN
        RAISE EXCEPTION 'The requested variety lot segment was not found'
            USING ERRCODE='23503';
    END IF;
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.tenant_id::text || ':production-batch:' || v_lock_batch::text,0)
    );
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
    IF (NEW.movement_type IN ('place','move_in') AND NEW.quantity_delta <= 0)
       OR (NEW.movement_type='move_out' AND NEW.quantity_delta >= 0) THEN
        RAISE EXCEPTION 'Placement movement direction does not match its movement type'
            USING ERRCODE='23514';
    END IF;
    IF NEW.movement_type IN ('harvest_remove','loss_remove','correction') THEN
        RAISE EXCEPTION 'Removal and correction movements require the M10.1.8 reconciliation command'
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
    SELECT COALESCE(sum(p.quantity_delta),0) + COALESCE((
               SELECT sum(l.quantity) FROM production_losses l
                WHERE l.tenant_id=NEW.tenant_id
                  AND l.production_lot_segment_id=NEW.production_lot_segment_id
                  AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
           ),0)
      INTO v_segment_balance
      FROM kumbung_placements p
     WHERE p.tenant_id=NEW.tenant_id AND p.production_lot_segment_id=NEW.production_lot_segment_id;
    IF NEW.movement_type='move_out' THEN
        SELECT COALESCE(sum(p.quantity_delta),0) - COALESCE((
                   SELECT sum(l.quantity) FROM production_losses l
                    WHERE l.tenant_id=NEW.tenant_id
                      AND l.production_lot_segment_id=NEW.production_lot_segment_id
                      AND l.source_kumbung_id=NEW.kumbung_id
                      AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
               ),0)
          INTO v_source_occupancy
          FROM kumbung_placements p
         WHERE p.tenant_id=NEW.tenant_id
           AND p.production_lot_segment_id=NEW.production_lot_segment_id
           AND p.kumbung_id=NEW.kumbung_id;
        IF v_source_occupancy + NEW.quantity_delta < 0 THEN
            RAISE EXCEPTION 'Move-out exceeds the quantity present in the source kumbung'
                USING ERRCODE='23514';
        END IF;
    ELSIF v_segment_balance + NEW.quantity_delta > v_segment_quantity THEN
        RAISE EXCEPTION 'Placement exceeds the unplaced variety lot segment quantity'
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
    SELECT count(*) INTO v_unconvertible
      FROM production_losses l
     WHERE l.tenant_id=NEW.tenant_id AND l.source_kumbung_id=NEW.kumbung_id
       AND l.stage='kumbung' AND l.unit_id <> v_kumbung_capacity_unit
       AND NOT EXISTS (
           SELECT 1 FROM measurement_unit_conversions c
            WHERE c.from_unit_id=l.unit_id AND c.to_unit_id=v_kumbung_capacity_unit
       );
    IF v_unconvertible > 0 THEN
        RAISE EXCEPTION 'Existing kumbung losses contain a unit without an explicit capacity conversion'
            USING ERRCODE='23514';
    END IF;
    SELECT COALESCE(sum(
               p.quantity_delta * CASE WHEN p.unit_id=v_kumbung_capacity_unit
                                       THEN 1 ELSE c.factor END
           ),0) - COALESCE((
               SELECT sum(l.quantity * CASE WHEN l.unit_id=v_kumbung_capacity_unit
                                            THEN 1 ELSE lc.factor END)
                 FROM production_losses l
                 LEFT JOIN measurement_unit_conversions lc
                   ON lc.from_unit_id=l.unit_id AND lc.to_unit_id=v_kumbung_capacity_unit
                WHERE l.tenant_id=NEW.tenant_id AND l.source_kumbung_id=NEW.kumbung_id
                  AND l.stage='kumbung'
                  AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
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

COMMIT;
),
    ADD CONSTRAINT production_losses_idempotency_pair_check
        CHECK ((idempotency_key IS NULL) = (request_hash IS NULL)),
    ADD CONSTRAINT production_losses_segment_fk
        FOREIGN KEY (tenant_id,production_lot_segment_id)
        REFERENCES production_lot_segments(tenant_id,id) ON DELETE RESTRICT,
    ADD CONSTRAINT production_losses_kumbung_fk
        FOREIGN KEY (tenant_id,source_kumbung_id)
        REFERENCES kumbungs(tenant_id,id) ON DELETE RESTRICT,
    ADD CONSTRAINT production_losses_kumbung_source_check
        CHECK (
            (stage='kumbung' AND production_lot_segment_id IS NOT NULL
                              AND source_kumbung_id IS NOT NULL)
            OR
            (stage<>'kumbung' AND production_lot_segment_id IS NULL
                               AND source_kumbung_id IS NULL)
        );

CREATE INDEX ix_production_losses_batch_stage
    ON production_losses(tenant_id,batch_id,stage,occurred_at);
CREATE INDEX ix_production_losses_segment
    ON production_losses(tenant_id,production_lot_segment_id,source_kumbung_id)
    WHERE production_lot_segment_id IS NOT NULL;

CREATE TABLE production_loss_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    loss_id uuid NOT NULL,
    event_type varchar(40) NOT NULL
        CHECK (event_type IN ('loss_recorded','loss_disposition_changed','loss_recovery_posted')),
    occurred_at timestamptz NOT NULL DEFAULT now(),
    actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (tenant_id,id),
    FOREIGN KEY (tenant_id,loss_id)
        REFERENCES production_losses(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_production_loss_events_history
    ON production_loss_events(tenant_id,loss_id,occurred_at,id);

ALTER TABLE production_recovery_lots
    ADD COLUMN inventory_document_id uuid,
    ADD COLUMN inventory_document_line_id uuid,
    ADD COLUMN recovered_by uuid REFERENCES users(id) ON DELETE SET NULL,
    ADD CONSTRAINT production_recovery_lot_document_fk
        FOREIGN KEY (tenant_id,inventory_document_id)
        REFERENCES inventory_documents(tenant_id,id) ON DELETE RESTRICT,
    ADD CONSTRAINT production_recovery_lot_line_fk
        FOREIGN KEY (tenant_id,inventory_document_line_id)
        REFERENCES inventory_document_lines(tenant_id,id) ON DELETE RESTRICT;
CREATE UNIQUE INDEX uq_production_recovery_loss
    ON production_recovery_lots(tenant_id,loss_id);

CREATE TABLE production_batch_reconciliations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    cost_snapshot_id uuid NOT NULL,
    output_quantity numeric(24,8) NOT NULL CHECK (output_quantity > 0),
    placed_quantity numeric(24,8) NOT NULL CHECK (placed_quantity >= 0),
    loss_quantity numeric(24,8) NOT NULL CHECK (loss_quantity >= 0),
    accounted_quantity numeric(24,8) NOT NULL CHECK (accounted_quantity > 0),
    currency char(3) NOT NULL,
    finalized_at timestamptz NOT NULL DEFAULT now(),
    finalized_by uuid REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE (tenant_id,id),
    UNIQUE (tenant_id,batch_id),
    FOREIGN KEY (tenant_id,batch_id)
        REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id,cost_snapshot_id)
        REFERENCES production_cost_snapshots(tenant_id,id) ON DELETE RESTRICT,
    CHECK (accounted_quantity = placed_quantity + loss_quantity),
    CHECK (accounted_quantity = output_quantity)
);
CREATE INDEX ix_production_batch_reconciliations_finalized
    ON production_batch_reconciliations(tenant_id,finalized_at DESC);

CREATE OR REPLACE FUNCTION guard_production_loss_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_batch_output numeric(24,8);
    v_lot_batch uuid;
    v_lot_quantity numeric(24,8);
    v_existing numeric(24,8);
    v_press_rejects numeric(24,8);
    v_segment_batch uuid;
    v_segment_lot uuid;
    v_segment_unit uuid;
    v_kumbung_location uuid;
    v_batch_location uuid;
    v_occupancy numeric(24,8);
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.tenant_id::text || ':production-batch:' || NEW.batch_id::text,0)
    );
    SELECT planned_output_quantity,location_id
      INTO v_batch_output,v_batch_location
      FROM production_batches
     WHERE tenant_id=NEW.tenant_id AND id=NEW.batch_id;
    IF v_batch_output IS NULL THEN
        RAISE EXCEPTION 'Loss requires a tenant-owned production batch'
            USING ERRCODE='23503';
    END IF;

    IF NEW.stage='press_baglog' THEN
        SELECT COALESCE(sum(good_quantity*0 + rejected_quantity),0)
          INTO v_press_rejects
          FROM production_press_outputs
         WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id;
        SELECT COALESCE(sum(quantity),0) INTO v_existing
          FROM production_losses
         WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id AND stage='press_baglog';
        IF v_existing + NEW.quantity > v_press_rejects THEN
            RAISE EXCEPTION 'Press rejection loss exceeds immutable rejected press output'
                USING ERRCODE='23514';
        END IF;
        IF NEW.production_lot_id IS NULL THEN
            RAISE EXCEPTION 'Press rejection loss must reference the posted production lot'
                USING ERRCODE='23514';
        END IF;
    ELSIF NEW.stage='mixing' THEN
        SELECT COALESCE(sum(quantity),0) INTO v_existing
          FROM production_losses
         WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id AND stage='mixing';
        IF v_existing + NEW.quantity > v_batch_output THEN
            RAISE EXCEPTION 'Mixing loss exceeds the batch planned output quantity'
                USING ERRCODE='23514';
        END IF;
        IF NEW.production_lot_id IS NOT NULL THEN
            RAISE EXCEPTION 'Mixing loss must be recorded before a production lot exists'
                USING ERRCODE='23514';
        END IF;
    ELSIF NEW.stage='kumbung' THEN
        SELECT s.batch_id,s.production_lot_id,s.unit_id,b.location_id
          INTO v_segment_batch,v_segment_lot,v_segment_unit,v_batch_location
          FROM production_lot_segments s
          JOIN production_batches b
            ON b.tenant_id=s.tenant_id AND b.id=s.batch_id
         WHERE s.tenant_id=NEW.tenant_id AND s.id=NEW.production_lot_segment_id;
        SELECT location_id INTO v_kumbung_location
          FROM kumbungs
         WHERE tenant_id=NEW.tenant_id AND id=NEW.source_kumbung_id AND is_active;
        IF v_segment_batch IS DISTINCT FROM NEW.batch_id
           OR v_segment_lot IS DISTINCT FROM NEW.production_lot_id
           OR v_segment_unit IS DISTINCT FROM NEW.unit_id
           OR v_kumbung_location IS DISTINCT FROM v_batch_location THEN
            RAISE EXCEPTION 'Kumbung loss must reference an available segment at the batch location'
                USING ERRCODE='23514';
        END IF;
        SELECT COALESCE(sum(quantity_delta),0) INTO v_occupancy
          FROM kumbung_placements
         WHERE tenant_id=NEW.tenant_id
           AND production_lot_segment_id=NEW.production_lot_segment_id
           AND kumbung_id=NEW.source_kumbung_id;
        SELECT v_occupancy - COALESCE(sum(quantity),0) INTO v_occupancy
          FROM production_losses
         WHERE tenant_id=NEW.tenant_id
           AND production_lot_segment_id=NEW.production_lot_segment_id
           AND source_kumbung_id=NEW.source_kumbung_id
           AND disposition IN ('recovered','recycled','permanent_loss','discarded');
        IF v_occupancy < NEW.quantity THEN
            RAISE EXCEPTION 'Kumbung loss exceeds the quantity currently present in that kumbung'
                USING ERRCODE='23514';
        END IF;
    ELSIF NEW.stage IN ('sterilization','cooling','inoculation','incubation','other') THEN
        SELECT batch_id,output_quantity INTO v_lot_batch,v_lot_quantity
          FROM production_lots
         WHERE tenant_id=NEW.tenant_id AND id=NEW.production_lot_id;
        IF v_lot_batch IS DISTINCT FROM NEW.batch_id THEN
            RAISE EXCEPTION 'Loss must reference a production lot from the same batch'
                USING ERRCODE='23514';
        END IF;
        SELECT COALESCE(sum(quantity),0) INTO v_existing
          FROM production_losses
         WHERE tenant_id=NEW.tenant_id AND production_lot_id=NEW.production_lot_id
           AND stage <> 'press_baglog';
        IF v_existing + NEW.quantity > v_lot_quantity THEN
            RAISE EXCEPTION 'Cumulative production losses exceed the source lot quantity'
                USING ERRCODE='23514';
        END IF;
    ELSE
        RAISE EXCEPTION 'Harvest loss is not enabled until the harvest domain is implemented'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_loss_insert_guard
    BEFORE INSERT ON production_losses
    FOR EACH ROW EXECUTE FUNCTION guard_production_loss_insert();

CREATE OR REPLACE FUNCTION guard_production_loss_mutation()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_recovery_quantity numeric(24,8);
    v_actor uuid;
BEGIN
    IF TG_OP='DELETE' THEN
        RAISE EXCEPTION 'Production loss records are append-only'
            USING ERRCODE='55000';
    END IF;
    IF (to_jsonb(NEW)-'disposition') <> (to_jsonb(OLD)-'disposition')
       OR OLD.disposition <> 'pending'
       OR NEW.disposition NOT IN ('recovered','recycled','permanent_loss','discarded') THEN
        RAISE EXCEPTION 'Only a pending loss may receive one terminal disposition'
            USING ERRCODE='55000';
    END IF;
    IF NEW.disposition IN ('recovered','recycled') THEN
        SELECT COALESCE(sum(recovered_quantity),0) INTO v_recovery_quantity
          FROM production_recovery_lots
         WHERE tenant_id=NEW.tenant_id AND loss_id=NEW.id;
        IF v_recovery_quantity <> NEW.quantity THEN
            RAISE EXCEPTION 'Recovered or recycled disposition requires a full matching recovery lot'
                USING ERRCODE='23514';
        END IF;
    END IF;
    v_actor := NULLIF(current_setting('app.user_id',true),'')::uuid;
    INSERT INTO production_loss_events(
        tenant_id,loss_id,event_type,actor_user_id,metadata
    ) VALUES (
        NEW.tenant_id,NEW.id,'loss_disposition_changed',v_actor,
        jsonb_build_object('from',OLD.disposition,'to',NEW.disposition)
    );
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_losses_mutation_guard
    BEFORE UPDATE OR DELETE ON production_losses
    FOR EACH ROW EXECUTE FUNCTION guard_production_loss_mutation();

CREATE OR REPLACE FUNCTION record_production_loss_event()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
BEGIN
    INSERT INTO production_loss_events(
        tenant_id,loss_id,event_type,occurred_at,actor_user_id,metadata
    ) VALUES (
        NEW.tenant_id,NEW.id,'loss_recorded',NEW.occurred_at,NEW.recorded_by,
        jsonb_build_object('stage',NEW.stage,'quantity',NEW.quantity,
                           'unit_id',NEW.unit_id,'reason_code',NEW.reason_code)
    );
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_loss_recorded_event
    AFTER INSERT ON production_losses
    FOR EACH ROW EXECUTE FUNCTION record_production_loss_event();

CREATE OR REPLACE FUNCTION guard_production_recovery_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_loss_quantity numeric(24,8);
    v_loss_recoverable boolean;
    v_loss_disposition varchar(30);
    v_document_type varchar(30);
    v_document_status varchar(20);
    v_line_document uuid;
    v_line_lot uuid;
    v_line_quantity numeric(24,8);
    v_ledger_quantity numeric(24,8);
    v_ledger_value numeric(24,8);
BEGIN
    SELECT quantity,recoverable,disposition
      INTO v_loss_quantity,v_loss_recoverable,v_loss_disposition
      FROM production_losses
     WHERE tenant_id=NEW.tenant_id AND id=NEW.loss_id
     FOR UPDATE;
    IF v_loss_quantity IS NULL OR v_loss_recoverable IS DISTINCT FROM true
       OR v_loss_disposition <> 'pending'
       OR NEW.recovered_quantity <> v_loss_quantity THEN
        RAISE EXCEPTION 'Recovery requires one full, recoverable, pending loss'
            USING ERRCODE='23514';
    END IF;
    SELECT document_type,status INTO v_document_type,v_document_status
      FROM inventory_documents
     WHERE tenant_id=NEW.tenant_id AND id=NEW.inventory_document_id;
    SELECT document_id,lot_id,quantity INTO v_line_document,v_line_lot,v_line_quantity
      FROM inventory_document_lines
     WHERE tenant_id=NEW.tenant_id AND id=NEW.inventory_document_line_id;
    SELECT quantity_delta,value_delta INTO v_ledger_quantity,v_ledger_value
      FROM inventory_ledger_entries
     WHERE tenant_id=NEW.tenant_id
       AND document_id=NEW.inventory_document_id
       AND document_line_id=NEW.inventory_document_line_id;
    IF v_document_type IS DISTINCT FROM 'recovery'
       OR v_document_status IS DISTINCT FROM 'posted'
       OR v_line_document IS DISTINCT FROM NEW.inventory_document_id
       OR v_line_lot IS DISTINCT FROM NEW.recovered_inventory_lot_id
       OR v_line_quantity IS DISTINCT FROM NEW.recovered_quantity
       OR v_ledger_quantity IS NULL OR v_ledger_quantity <= 0
       OR v_ledger_value IS DISTINCT FROM (NEW.original_cost_snapshot + NEW.recovery_cost_snapshot) THEN
        RAISE EXCEPTION 'Recovery record requires its matching posted recovery document and stock ledger'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_recovery_insert_guard
    BEFORE INSERT ON production_recovery_lots
    FOR EACH ROW EXECUTE FUNCTION guard_production_recovery_insert();
CREATE TRIGGER production_recovery_lots_immutable
    BEFORE UPDATE OR DELETE ON production_recovery_lots
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

CREATE OR REPLACE FUNCTION record_recovery_event()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
BEGIN
    INSERT INTO production_loss_events(
        tenant_id,loss_id,event_type,actor_user_id,metadata
    ) VALUES (
        NEW.tenant_id,NEW.loss_id,'loss_recovery_posted',NEW.recovered_by,
        jsonb_build_object('recovery_lot_id',NEW.id,
                           'recovered_quantity',NEW.recovered_quantity,
                           'total_recovery_cost',NEW.total_recovery_cost,
                           'currency',NEW.currency)
    );
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_recovery_event
    AFTER INSERT ON production_recovery_lots
    FOR EACH ROW EXECUTE FUNCTION record_recovery_event();

CREATE OR REPLACE FUNCTION guard_production_batch_reconciliation_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1018$
DECLARE
    v_status varchar(30);
    v_output numeric(24,8);
    v_placed numeric(24,8);
    v_losses numeric(24,8);
    v_pending bigint;
    v_missing_recovery bigint;
    v_snapshot_batch uuid;
    v_snapshot_output numeric(24,8);
    v_snapshot_currency char(3);
BEGIN
    SELECT status INTO v_status
      FROM production_batches
     WHERE tenant_id=NEW.tenant_id AND id=NEW.batch_id
     FOR UPDATE;
    SELECT COALESCE(sum(output_quantity),0) INTO v_output
      FROM production_lots
     WHERE tenant_id=NEW.tenant_id AND batch_id=NEW.batch_id;
    SELECT COALESCE(sum(p.quantity_delta),0) - COALESCE((
               SELECT sum(l.quantity) FROM production_losses l
                WHERE l.tenant_id=NEW.tenant_id AND l.batch_id=NEW.batch_id
                  AND l.stage='kumbung'
                  AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
           ),0) INTO v_placed
      FROM kumbung_placements p
      JOIN production_lot_segments s
        ON s.tenant_id=p.tenant_id AND s.id=p.production_lot_segment_id
     WHERE p.tenant_id=NEW.tenant_id AND s.batch_id=NEW.batch_id;
    SELECT COALESCE(sum(quantity),0),
           count(*) FILTER (WHERE disposition='pending'),
           count(*) FILTER (
               WHERE disposition IN ('recovered','recycled')
                 AND NOT EXISTS (
                     SELECT 1 FROM production_recovery_lots r
                      WHERE r.tenant_id=l.tenant_id AND r.loss_id=l.id
                        AND r.recovered_quantity=l.quantity
                 )
           )
      INTO v_losses,v_pending,v_missing_recovery
      FROM production_losses l
     WHERE l.tenant_id=NEW.tenant_id AND l.batch_id=NEW.batch_id
       AND l.stage <> 'press_baglog';
    SELECT batch_id,output_quantity,currency
      INTO v_snapshot_batch,v_snapshot_output,v_snapshot_currency
      FROM production_cost_snapshots
     WHERE tenant_id=NEW.tenant_id AND id=NEW.cost_snapshot_id;
    IF v_status IS DISTINCT FROM 'ready'
       OR v_snapshot_batch IS DISTINCT FROM NEW.batch_id
       OR v_snapshot_output IS DISTINCT FROM NEW.output_quantity
       OR v_snapshot_currency IS DISTINCT FROM NEW.currency
       OR v_pending <> 0 OR v_missing_recovery <> 0
       OR v_output <> NEW.output_quantity
       OR v_placed <> NEW.placed_quantity
       OR v_losses <> NEW.loss_quantity
       OR v_placed + v_losses <> v_output
       OR NEW.accounted_quantity <> v_output THEN
        RAISE EXCEPTION 'Batch output, placements, losses, recovery and cost snapshot do not reconcile'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1018$;
CREATE TRIGGER production_batch_reconciliation_insert_guard
    BEFORE INSERT ON production_batch_reconciliations
    FOR EACH ROW EXECUTE FUNCTION guard_production_batch_reconciliation_insert();

CREATE TRIGGER production_loss_events_immutable
    BEFORE UPDATE OR DELETE ON production_loss_events
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();
CREATE TRIGGER production_batch_reconciliations_immutable
    BEFORE UPDATE OR DELETE ON production_batch_reconciliations
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

ALTER TABLE production_loss_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_loss_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON production_loss_events
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());
ALTER TABLE production_batch_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_batch_reconciliations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON production_batch_reconciliations
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());

-- Update the occupancy view to account for append-only kumbung loss records.
CREATE OR REPLACE VIEW kumbung_stock WITH (security_invoker=true) AS
SELECT p.tenant_id,p.kumbung_id,p.production_lot_id,p.unit_id,
       sum(p.quantity_delta) - COALESCE((
           SELECT sum(l.quantity)
             FROM production_losses l
            WHERE l.tenant_id=p.tenant_id
              AND l.stage='kumbung'
              AND l.source_kumbung_id=p.kumbung_id
              AND l.production_lot_id=p.production_lot_id
              AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
       ),0) AS quantity_present
  FROM kumbung_placements p
 GROUP BY p.tenant_id,p.kumbung_id,p.production_lot_id,p.unit_id;

GRANT SELECT,INSERT ON production_loss_events TO miselium_app;
GRANT SELECT,UPDATE (disposition) ON production_losses TO miselium_app;
GRANT SELECT,INSERT ON production_recovery_lots TO miselium_app;
GRANT SELECT,INSERT ON production_batch_reconciliations TO miselium_app;
GRANT SELECT,INSERT ON production_cost_snapshots TO miselium_app;
GRANT SELECT ON production_machine_cost_allocations,production_lot_segments,
    kumbung_placements,production_lots,production_press_outputs,
    production_batches,inventory_item_units,inventory_items,measurement_units,
    inventory_stock_by_warehouse TO miselium_app;
GRANT INSERT ON inventory_lots,inventory_documents,inventory_document_lines,
    inventory_ledger_entries,tenant_audit_events TO miselium_app;

-- Keep placement capacity and available-segment checks consistent with loss records.
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
    v_source_occupancy numeric(24,8);
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
    IF (NEW.movement_type IN ('place','move_in') AND NEW.quantity_delta <= 0)
       OR (NEW.movement_type='move_out' AND NEW.quantity_delta >= 0) THEN
        RAISE EXCEPTION 'Placement movement direction does not match its movement type'
            USING ERRCODE='23514';
    END IF;
    IF NEW.movement_type IN ('harvest_remove','loss_remove','correction') THEN
        RAISE EXCEPTION 'Removal and correction movements require the M10.1.8 reconciliation command'
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
    SELECT COALESCE(sum(p.quantity_delta),0) + COALESCE((
               SELECT sum(l.quantity) FROM production_losses l
                WHERE l.tenant_id=NEW.tenant_id
                  AND l.production_lot_segment_id=NEW.production_lot_segment_id
                  AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
           ),0)
      INTO v_segment_balance
      FROM kumbung_placements p
     WHERE p.tenant_id=NEW.tenant_id AND p.production_lot_segment_id=NEW.production_lot_segment_id;
    IF NEW.movement_type='move_out' THEN
        SELECT COALESCE(sum(p.quantity_delta),0) - COALESCE((
                   SELECT sum(l.quantity) FROM production_losses l
                    WHERE l.tenant_id=NEW.tenant_id
                      AND l.production_lot_segment_id=NEW.production_lot_segment_id
                      AND l.source_kumbung_id=NEW.kumbung_id
                      AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
               ),0)
          INTO v_source_occupancy
          FROM kumbung_placements p
         WHERE p.tenant_id=NEW.tenant_id
           AND p.production_lot_segment_id=NEW.production_lot_segment_id
           AND p.kumbung_id=NEW.kumbung_id;
        IF v_source_occupancy + NEW.quantity_delta < 0 THEN
            RAISE EXCEPTION 'Move-out exceeds the quantity present in the source kumbung'
                USING ERRCODE='23514';
        END IF;
    ELSIF v_segment_balance + NEW.quantity_delta > v_segment_quantity THEN
        RAISE EXCEPTION 'Placement exceeds the unplaced variety lot segment quantity'
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
    SELECT count(*) INTO v_unconvertible
      FROM production_losses l
     WHERE l.tenant_id=NEW.tenant_id AND l.source_kumbung_id=NEW.kumbung_id
       AND l.stage='kumbung' AND l.unit_id <> v_kumbung_capacity_unit
       AND NOT EXISTS (
           SELECT 1 FROM measurement_unit_conversions c
            WHERE c.from_unit_id=l.unit_id AND c.to_unit_id=v_kumbung_capacity_unit
       );
    IF v_unconvertible > 0 THEN
        RAISE EXCEPTION 'Existing kumbung losses contain a unit without an explicit capacity conversion'
            USING ERRCODE='23514';
    END IF;
    SELECT COALESCE(sum(
               p.quantity_delta * CASE WHEN p.unit_id=v_kumbung_capacity_unit
                                       THEN 1 ELSE c.factor END
           ),0) - COALESCE((
               SELECT sum(l.quantity * CASE WHEN l.unit_id=v_kumbung_capacity_unit
                                            THEN 1 ELSE lc.factor END)
                 FROM production_losses l
                 LEFT JOIN measurement_unit_conversions lc
                   ON lc.from_unit_id=l.unit_id AND lc.to_unit_id=v_kumbung_capacity_unit
                WHERE l.tenant_id=NEW.tenant_id AND l.source_kumbung_id=NEW.kumbung_id
                  AND l.stage='kumbung'
                  AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
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

COMMIT;
