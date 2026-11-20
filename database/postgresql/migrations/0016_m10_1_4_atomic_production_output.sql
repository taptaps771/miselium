-- Miselium M10.1.4 / 0016 Atomic production output posting
-- PostgreSQL 16+. Requires migrations 0001-0015.
-- Additive: records one immutable stock posting for each completed press batch.
BEGIN;

CREATE TABLE production_output_postings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    inventory_document_id uuid NOT NULL,
    inventory_document_line_id uuid NOT NULL,
    production_lot_id uuid NOT NULL,
    output_quantity numeric(24,8) NOT NULL CHECK (output_quantity > 0),
    material_cost_snapshot numeric(24,8) NOT NULL CHECK (material_cost_snapshot >= 0),
    currency char(3) NOT NULL,
    posted_at timestamptz NOT NULL DEFAULT now(),
    posted_by uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, id),
    UNIQUE (tenant_id, batch_id),
    UNIQUE (tenant_id, inventory_document_id),
    UNIQUE (tenant_id, inventory_document_line_id),
    UNIQUE (tenant_id, production_lot_id),
    FOREIGN KEY (tenant_id, batch_id)
        REFERENCES production_batches(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, inventory_document_id)
        REFERENCES inventory_documents(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, inventory_document_line_id)
        REFERENCES inventory_document_lines(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, production_lot_id)
        REFERENCES production_lots(tenant_id, id) ON DELETE RESTRICT
);

CREATE INDEX ix_production_output_postings_batch_time
    ON production_output_postings(tenant_id, batch_id, posted_at DESC);

CREATE OR REPLACE FUNCTION guard_production_output_posting_insert()
RETURNS trigger LANGUAGE plpgsql AS $m1014$
DECLARE
    v_batch_status varchar(30);
    v_document_type varchar(30);
    v_document_status varchar(20);
    v_source_type varchar(60);
    v_source_id uuid;
    v_line_document_id uuid;
    v_line_lot_id uuid;
    v_line_base_quantity numeric(24,8);
    v_line_quantity numeric(24,8);
    v_line_unit_id uuid;
    v_lot_batch_id uuid;
    v_lot_inventory_id uuid;
    v_lot_quantity numeric(24,8);
    v_lot_unit_id uuid;
    v_batch_output_unit_id uuid;
BEGIN
    SELECT status, output_unit_id INTO v_batch_status, v_batch_output_unit_id
      FROM production_batches
     WHERE tenant_id=NEW.tenant_id AND id=NEW.batch_id;
    IF v_batch_status IS DISTINCT FROM 'sterilization' THEN
        RAISE EXCEPTION 'Production output can only be posted after press completion'
            USING ERRCODE='23514';
    END IF;

    SELECT document_type, status, source_reference_type, source_reference_id
      INTO v_document_type, v_document_status, v_source_type, v_source_id
      FROM inventory_documents
     WHERE tenant_id=NEW.tenant_id AND id=NEW.inventory_document_id;
    IF v_document_type IS DISTINCT FROM 'production_output'
       OR v_document_status IS DISTINCT FROM 'posted'
       OR v_source_type IS DISTINCT FROM 'production_batch'
       OR v_source_id IS DISTINCT FROM NEW.batch_id THEN
        RAISE EXCEPTION 'Production output posting must reference its posted batch output document'
            USING ERRCODE='23514';
    END IF;

    SELECT document_id, lot_id, base_quantity, quantity, unit_id
      INTO v_line_document_id, v_line_lot_id, v_line_base_quantity,
           v_line_quantity, v_line_unit_id
      FROM inventory_document_lines
     WHERE tenant_id=NEW.tenant_id AND id=NEW.inventory_document_line_id;
    IF v_line_document_id IS DISTINCT FROM NEW.inventory_document_id THEN
        RAISE EXCEPTION 'Production output line must belong to the output document'
            USING ERRCODE='23514';
    END IF;

    SELECT batch_id, inventory_lot_id, output_quantity, output_unit_id
      INTO v_lot_batch_id, v_lot_inventory_id, v_lot_quantity, v_lot_unit_id
      FROM production_lots
     WHERE tenant_id=NEW.tenant_id AND id=NEW.production_lot_id;
    IF v_lot_batch_id IS DISTINCT FROM NEW.batch_id
       OR v_lot_inventory_id IS DISTINCT FROM v_line_lot_id
       OR v_lot_quantity IS DISTINCT FROM NEW.output_quantity
       OR v_line_quantity IS DISTINCT FROM NEW.output_quantity
       OR v_line_unit_id IS DISTINCT FROM v_batch_output_unit_id
       OR v_lot_unit_id IS DISTINCT FROM v_batch_output_unit_id THEN
        RAISE EXCEPTION 'Production lot must match the posted batch output and inventory lot'
            USING ERRCODE='23514';
    END IF;
    IF v_line_base_quantity IS NULL OR v_line_base_quantity <= 0 THEN
        RAISE EXCEPTION 'Production output line must have a positive base quantity'
            USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$m1014$;

CREATE TRIGGER production_output_posting_insert_guard
    BEFORE INSERT ON production_output_postings
    FOR EACH ROW EXECUTE FUNCTION guard_production_output_posting_insert();

CREATE TRIGGER production_output_postings_immutable
    BEFORE UPDATE OR DELETE ON production_output_postings
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

ALTER TABLE production_output_postings ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_output_postings FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON production_output_postings
    USING (tenant_id=current_tenant_id())
    WITH CHECK (tenant_id=current_tenant_id());

-- The output service inserts the generated lot and production lot, then posts
-- the document and ledger in the same caller-owned transaction.
GRANT SELECT, INSERT ON production_output_postings TO miselium_app;
GRANT INSERT ON inventory_lots, production_lots TO miselium_app;
GRANT UPDATE (actual_output_quantity, updated_at) ON production_batches TO miselium_app;
GRANT SELECT ON inventory_item_units, measurement_units, production_units TO miselium_app;
GRANT SELECT, INSERT ON production_batch_events TO miselium_app;
GRANT INSERT ON tenant_audit_events TO miselium_app;

COMMIT;
