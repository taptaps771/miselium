-- Miselium M10 / 0002 Production & Inventory Foundation
-- Requires M9 0001_platform_foundation.sql. PostgreSQL 16+.
BEGIN;

CREATE TABLE measurement_units (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 code varchar(30) NOT NULL UNIQUE,
 name varchar(80) NOT NULL,
 dimension varchar(20) NOT NULL CHECK (dimension IN ('mass','volume','count','length','area','time','other')),
 decimal_places smallint NOT NULL DEFAULT 3 CHECK (decimal_places BETWEEN 0 AND 8),
 is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE inventory_categories (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
 code varchar(50) NOT NULL, name varchar(120) NOT NULL, description text,
 is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,code), UNIQUE (tenant_id,id)
);
CREATE TABLE inventory_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
 category_id uuid, code varchar(80) NOT NULL, name varchar(180) NOT NULL, description text,
 item_type varchar(30) NOT NULL CHECK (item_type IN ('raw_material','packaging','seed','work_in_process','finished_good','consumable','other')),
 base_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
 is_lot_tracked boolean NOT NULL DEFAULT false, allow_negative_stock boolean NOT NULL DEFAULT false,
 is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,code), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,category_id) REFERENCES inventory_categories(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_inventory_items_category ON inventory_items(tenant_id,category_id);
CREATE INDEX ix_inventory_items_type_active ON inventory_items(tenant_id,item_type,is_active);

CREATE TABLE inventory_item_units (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, item_id uuid NOT NULL,
 unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
 conversion_to_base numeric(24,10) NOT NULL CHECK (conversion_to_base > 0),
 is_purchase_unit boolean NOT NULL DEFAULT false, is_issue_unit boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (tenant_id,item_id,unit_id), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,item_id) REFERENCES inventory_items(tenant_id,id) ON DELETE CASCADE
);
CREATE TABLE inventory_lots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, item_id uuid NOT NULL,
 lot_code varchar(100) NOT NULL, supplier_lot_code varchar(100), manufactured_at date, expires_at date,
 received_at timestamptz, status varchar(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','quarantined','expired','closed')),
 attributes jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,item_id,lot_code), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,item_id) REFERENCES inventory_items(tenant_id,id) ON DELETE RESTRICT,
 CHECK (expires_at IS NULL OR manufactured_at IS NULL OR expires_at >= manufactured_at)
);
CREATE INDEX ix_inventory_lots_expiry ON inventory_lots(tenant_id,expires_at) WHERE status='active';

CREATE TABLE inventory_documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
 document_no varchar(60) NOT NULL,
 document_type varchar(30) NOT NULL CHECK (document_type IN ('receipt','issue','transfer','adjustment','production_consumption','production_output','return','recovery')),
 status varchar(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','posted','reversed','cancelled')),
 source_warehouse_id uuid, destination_warehouse_id uuid, occurred_at timestamptz NOT NULL DEFAULT now(),
 posted_at timestamptz, posted_by uuid REFERENCES users(id) ON DELETE SET NULL,
 reversed_document_id uuid, source_reference_type varchar(60), source_reference_id uuid, idempotency_key varchar(120),
 notes text, created_by uuid REFERENCES users(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,document_no), UNIQUE (tenant_id,id), UNIQUE (tenant_id,idempotency_key),
 FOREIGN KEY (tenant_id,source_warehouse_id) REFERENCES warehouses(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,destination_warehouse_id) REFERENCES warehouses(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,reversed_document_id) REFERENCES inventory_documents(tenant_id,id) ON DELETE RESTRICT,
 CHECK (source_warehouse_id IS NULL OR destination_warehouse_id IS NULL OR source_warehouse_id<>destination_warehouse_id),
 CHECK ((status='posted' AND posted_at IS NOT NULL) OR (status<>'posted' AND posted_at IS NULL))
);
CREATE INDEX ix_inventory_docs_status_time ON inventory_documents(tenant_id,status,occurred_at DESC);
CREATE INDEX ix_inventory_docs_source_ref ON inventory_documents(tenant_id,source_reference_type,source_reference_id);

CREATE TABLE inventory_document_lines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, document_id uuid NOT NULL,
 line_no integer NOT NULL CHECK (line_no>0), item_id uuid NOT NULL, lot_id uuid,
 item_code_snapshot varchar(80) NOT NULL, item_name_snapshot varchar(180) NOT NULL,
 quantity numeric(24,8) NOT NULL CHECK (quantity>0), unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
 unit_name_snapshot varchar(80) NOT NULL, conversion_to_base_snapshot numeric(24,10) NOT NULL CHECK (conversion_to_base_snapshot>0),
 base_quantity numeric(24,8) NOT NULL CHECK (base_quantity>0), unit_cost_snapshot numeric(24,8) NOT NULL DEFAULT 0 CHECK (unit_cost_snapshot>=0),
 currency char(3) NOT NULL DEFAULT 'IDR', line_value_snapshot numeric(24,8) NOT NULL DEFAULT 0 CHECK (line_value_snapshot>=0),
 notes text, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,document_id,line_no), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,document_id) REFERENCES inventory_documents(tenant_id,id) ON DELETE CASCADE,
 FOREIGN KEY (tenant_id,item_id) REFERENCES inventory_items(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,lot_id) REFERENCES inventory_lots(tenant_id,id) ON DELETE RESTRICT,
 CHECK (abs(base_quantity-quantity*conversion_to_base_snapshot)<=0.0000001)
);
CREATE INDEX ix_inventory_doc_lines_item ON inventory_document_lines(tenant_id,item_id,document_id);

CREATE TABLE inventory_ledger_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, document_id uuid NOT NULL, document_line_id uuid NOT NULL,
 warehouse_id uuid NOT NULL, item_id uuid NOT NULL, lot_id uuid,
 quantity_delta numeric(24,8) NOT NULL CHECK (quantity_delta<>0), value_delta numeric(24,8) NOT NULL,
 currency char(3) NOT NULL, unit_cost_snapshot numeric(24,8) NOT NULL CHECK (unit_cost_snapshot>=0),
 occurred_at timestamptz NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now(), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,document_id) REFERENCES inventory_documents(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,document_line_id) REFERENCES inventory_document_lines(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,warehouse_id) REFERENCES warehouses(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,item_id) REFERENCES inventory_items(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,lot_id) REFERENCES inventory_lots(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_inventory_ledger_balance ON inventory_ledger_entries(tenant_id,warehouse_id,item_id,lot_id,occurred_at);
CREATE INDEX ix_inventory_ledger_document ON inventory_ledger_entries(tenant_id,document_id);
CREATE VIEW inventory_stock_by_warehouse WITH (security_invoker=true) AS
 SELECT tenant_id,warehouse_id,item_id,lot_id,currency,sum(quantity_delta) quantity_on_hand,sum(value_delta) inventory_value
 FROM inventory_ledger_entries GROUP BY tenant_id,warehouse_id,item_id,lot_id,currency;

CREATE TABLE recipes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
 code varchar(60) NOT NULL, name varchar(160) NOT NULL,
 production_type varchar(30) NOT NULL CHECK (production_type IN ('bibit','baglog','other')),
 output_item_id uuid NOT NULL, is_active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,code), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,output_item_id) REFERENCES inventory_items(tenant_id,id) ON DELETE RESTRICT
);
CREATE TABLE recipe_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, recipe_id uuid NOT NULL,
 version_no integer NOT NULL CHECK (version_no>0), output_quantity numeric(24,8) NOT NULL CHECK (output_quantity>0),
 output_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT, instructions text,
 status varchar(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','retired')),
 activated_at timestamptz, created_by uuid REFERENCES users(id) ON DELETE SET NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,recipe_id,version_no), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,recipe_id) REFERENCES recipes(tenant_id,id) ON DELETE RESTRICT
);
CREATE TABLE recipe_version_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, recipe_version_id uuid NOT NULL,
 line_no integer NOT NULL CHECK (line_no>0), item_id uuid NOT NULL, quantity numeric(24,8) NOT NULL CHECK (quantity>0),
 unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
 conversion_to_base_snapshot numeric(24,10) NOT NULL CHECK (conversion_to_base_snapshot>0),
 item_code_snapshot varchar(80) NOT NULL, item_name_snapshot varchar(180) NOT NULL, unit_name_snapshot varchar(80) NOT NULL, notes text,
 UNIQUE (tenant_id,recipe_version_id,line_no), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,recipe_version_id) REFERENCES recipe_versions(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,item_id) REFERENCES inventory_items(tenant_id,id) ON DELETE RESTRICT
);

CREATE TABLE production_batches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
 location_id uuid NOT NULL, production_unit_id uuid NOT NULL, batch_code varchar(70) NOT NULL,
 recipe_version_id uuid NOT NULL, production_type varchar(30) NOT NULL CHECK (production_type IN ('bibit','baglog','other')),
 status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','planned','mixing','sterilization','cooling','inoculation','incubation','ready','on_hold','closed','cancelled')),
 planned_output_quantity numeric(24,8) NOT NULL CHECK (planned_output_quantity>0),
 actual_output_quantity numeric(24,8) CHECK (actual_output_quantity IS NULL OR actual_output_quantity>=0),
 output_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
 started_at timestamptz, completed_at timestamptz, created_by uuid REFERENCES users(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,batch_code), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,location_id) REFERENCES locations(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,production_unit_id) REFERENCES production_units(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,recipe_version_id) REFERENCES recipe_versions(tenant_id,id) ON DELETE RESTRICT,
 CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at>=started_at)
);
CREATE INDEX ix_production_batches_status ON production_batches(tenant_id,status,created_at DESC);
CREATE INDEX ix_production_batches_unit ON production_batches(tenant_id,production_unit_id,created_at DESC);

CREATE TABLE production_batch_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, batch_id uuid NOT NULL,
 event_type varchar(50) NOT NULL, from_status varchar(30), to_status varchar(30),
 quantity numeric(24,8), unit_id uuid REFERENCES measurement_units(id) ON DELETE RESTRICT,
 occurred_at timestamptz NOT NULL DEFAULT now(), actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
 notes text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb, UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_batch_events_history ON production_batch_events(tenant_id,batch_id,occurred_at);
CREATE TABLE production_batch_consumptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, batch_id uuid NOT NULL,
 inventory_document_line_id uuid NOT NULL, item_id uuid NOT NULL,
 consumed_base_quantity numeric(24,8) NOT NULL CHECK (consumed_base_quantity>0),
 material_cost_snapshot numeric(24,8) NOT NULL CHECK (material_cost_snapshot>=0),
 currency char(3) NOT NULL, consumed_at timestamptz NOT NULL,
 UNIQUE (tenant_id,inventory_document_line_id), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,inventory_document_line_id) REFERENCES inventory_document_lines(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,item_id) REFERENCES inventory_items(tenant_id,id) ON DELETE RESTRICT
);

CREATE TABLE sterilizers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, production_unit_id uuid NOT NULL,
 code varchar(50) NOT NULL, name varchar(120) NOT NULL, capacity numeric(24,8) NOT NULL CHECK (capacity>0),
 capacity_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
 cycle_minutes integer NOT NULL CHECK (cycle_minutes>0), cooling_minutes integer NOT NULL DEFAULT 0 CHECK (cooling_minutes>=0),
 is_active boolean NOT NULL DEFAULT true, UNIQUE (tenant_id,code), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,production_unit_id) REFERENCES production_units(tenant_id,id) ON DELETE RESTRICT
);
CREATE TABLE sterilization_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, sterilizer_id uuid NOT NULL,
 run_code varchar(70) NOT NULL, status varchar(20) NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','running','completed','failed','cancelled')),
 started_at timestamptz, completed_at timestamptz, actual_temperature numeric(8,2), pressure_value numeric(10,3), pressure_unit varchar(20),
 operator_user_id uuid REFERENCES users(id) ON DELETE SET NULL, notes text, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,run_code), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,sterilizer_id) REFERENCES sterilizers(tenant_id,id) ON DELETE RESTRICT,
 CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at>=started_at)
);
CREATE TABLE sterilization_run_batches (
 tenant_id uuid NOT NULL, sterilization_run_id uuid NOT NULL, batch_id uuid NOT NULL,
 allocated_quantity numeric(24,8) NOT NULL CHECK (allocated_quantity>0),
 quantity_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (tenant_id,sterilization_run_id,batch_id),
 FOREIGN KEY (tenant_id,sterilization_run_id) REFERENCES sterilization_runs(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT
);

CREATE TABLE mushroom_varieties (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
 code varchar(50) NOT NULL, name varchar(120) NOT NULL, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,code), UNIQUE (tenant_id,id)
);
CREATE TABLE inoculation_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, production_unit_id uuid NOT NULL,
 run_code varchar(70) NOT NULL, status varchar(20) NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','running','completed','cancelled')),
 started_at timestamptz, completed_at timestamptz, operator_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
 notes text, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (tenant_id,run_code), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,production_unit_id) REFERENCES production_units(tenant_id,id) ON DELETE RESTRICT
);
CREATE TABLE inoculation_allocations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, inoculation_run_id uuid NOT NULL,
 batch_id uuid NOT NULL, variety_id uuid NOT NULL, allocated_quantity numeric(24,8) NOT NULL CHECK (allocated_quantity>0),
 quantity_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT, seed_lot_id uuid, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,inoculation_run_id,batch_id,variety_id), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,inoculation_run_id) REFERENCES inoculation_runs(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,variety_id) REFERENCES mushroom_varieties(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,seed_lot_id) REFERENCES inventory_lots(tenant_id,id) ON DELETE RESTRICT
);

CREATE TABLE incubation_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, batch_id uuid NOT NULL,
 sequence_no integer NOT NULL DEFAULT 1 CHECK (sequence_no>0), incubation_location_id uuid NOT NULL,
 started_at timestamptz NOT NULL, target_days integer NOT NULL CHECK (target_days>0), expected_move_at timestamptz NOT NULL,
 actual_move_at timestamptz, status varchar(20) NOT NULL DEFAULT 'incubating' CHECK (status IN ('incubating','ready_to_move','moved','cancelled')),
 notes text, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (tenant_id,batch_id,sequence_no), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,incubation_location_id) REFERENCES locations(tenant_id,id) ON DELETE RESTRICT,
 CHECK (expected_move_at>=started_at), CHECK (actual_move_at IS NULL OR actual_move_at>=started_at)
);
CREATE TABLE production_lots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, batch_id uuid NOT NULL, inventory_lot_id uuid NOT NULL,
 variety_id uuid, output_quantity numeric(24,8) NOT NULL CHECK (output_quantity>0),
 output_unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT, produced_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (tenant_id,inventory_lot_id), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,inventory_lot_id) REFERENCES inventory_lots(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,variety_id) REFERENCES mushroom_varieties(tenant_id,id) ON DELETE RESTRICT
);
CREATE TABLE kumbung_placements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, production_lot_id uuid NOT NULL, kumbung_id uuid NOT NULL,
 movement_type varchar(20) NOT NULL CHECK (movement_type IN ('place','move_in','move_out','harvest_remove','loss_remove','correction')),
 quantity_delta numeric(24,8) NOT NULL CHECK (quantity_delta<>0), unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
 occurred_at timestamptz NOT NULL DEFAULT now(), reference_id uuid, notes text, actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
 UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,production_lot_id) REFERENCES production_lots(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,kumbung_id) REFERENCES kumbungs(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX ix_kumbung_placements_balance ON kumbung_placements(tenant_id,kumbung_id,production_lot_id,occurred_at);
CREATE VIEW kumbung_stock WITH (security_invoker=true) AS
 SELECT tenant_id,kumbung_id,production_lot_id,unit_id,sum(quantity_delta) quantity_present
 FROM kumbung_placements GROUP BY tenant_id,kumbung_id,production_lot_id,unit_id;

CREATE TABLE production_losses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, batch_id uuid NOT NULL, production_lot_id uuid,
 stage varchar(30) NOT NULL CHECK (stage IN ('mixing','sterilization','cooling','inoculation','incubation','kumbung','harvest','other')),
 reason_code varchar(50) NOT NULL, quantity numeric(24,8) NOT NULL CHECK (quantity>0),
 unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT, recoverable boolean NOT NULL DEFAULT false,
 disposition varchar(30) NOT NULL DEFAULT 'pending' CHECK (disposition IN ('pending','recovered','recycled','permanent_loss','discarded')),
 occurred_at timestamptz NOT NULL DEFAULT now(), recorded_by uuid REFERENCES users(id) ON DELETE SET NULL, notes text,
 UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,production_lot_id) REFERENCES production_lots(tenant_id,id) ON DELETE RESTRICT
);
CREATE TABLE production_recovery_lots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, loss_id uuid NOT NULL, recovered_inventory_lot_id uuid NOT NULL,
 recovered_quantity numeric(24,8) NOT NULL CHECK (recovered_quantity>0), unit_id uuid NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
 original_cost_snapshot numeric(24,8) NOT NULL CHECK (original_cost_snapshot>=0),
 recovery_cost_snapshot numeric(24,8) NOT NULL CHECK (recovery_cost_snapshot>=0),
 total_recovery_cost numeric(24,8) GENERATED ALWAYS AS (original_cost_snapshot+recovery_cost_snapshot) STORED,
 currency char(3) NOT NULL, recovered_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,recovered_inventory_lot_id),
 FOREIGN KEY (tenant_id,loss_id) REFERENCES production_losses(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY (tenant_id,recovered_inventory_lot_id) REFERENCES inventory_lots(tenant_id,id) ON DELETE RESTRICT
);
CREATE TABLE production_cost_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, batch_id uuid NOT NULL,
 output_quantity numeric(24,8) NOT NULL CHECK (output_quantity>0), material_cost numeric(24,8) NOT NULL CHECK (material_cost>=0),
 overhead_cost numeric(24,8) NOT NULL DEFAULT 0 CHECK (overhead_cost>=0),
 total_cost numeric(24,8) GENERATED ALWAYS AS (material_cost+overhead_cost) STORED,
 unit_cost numeric(24,10) GENERATED ALWAYS AS ((material_cost+overhead_cost)/output_quantity) STORED,
 currency char(3) NOT NULL, finalized_at timestamptz NOT NULL DEFAULT now(), finalized_by uuid REFERENCES users(id) ON DELETE SET NULL,
 UNIQUE (tenant_id,batch_id), UNIQUE (tenant_id,id),
 FOREIGN KEY (tenant_id,batch_id) REFERENCES production_batches(tenant_id,id) ON DELETE RESTRICT
);

CREATE OR REPLACE FUNCTION reject_immutable_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Immutable record: % is not allowed',TG_OP USING ERRCODE='55000'; END;
$$;
CREATE TRIGGER inventory_ledger_immutable BEFORE UPDATE OR DELETE ON inventory_ledger_entries FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();
CREATE TRIGGER kumbung_placements_immutable BEFORE UPDATE OR DELETE ON kumbung_placements FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();
CREATE TRIGGER production_cost_snapshots_immutable BEFORE UPDATE OR DELETE ON production_cost_snapshots FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

-- Posted documents and their lines are immutable. Lines are guarded on INSERT too,
-- otherwise a caller could append a new line after posting.
CREATE OR REPLACE FUNCTION guard_posted_inventory_document()
RETURNS trigger LANGUAGE plpgsql AS $
DECLARE v_tenant uuid; v_document uuid; v_status varchar(20);
BEGIN
 IF TG_TABLE_NAME='inventory_documents' THEN
   IF OLD.status='posted' THEN
     RAISE EXCEPTION 'Posted inventory document is immutable; reverse it instead' USING ERRCODE='55000';
   END IF;
   IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
 END IF;
 IF TG_OP IN ('UPDATE','DELETE') THEN
   SELECT status INTO v_status FROM inventory_documents
    WHERE tenant_id=OLD.tenant_id AND id=OLD.document_id;
   IF v_status='posted' THEN
     RAISE EXCEPTION 'Lines of posted inventory document are immutable' USING ERRCODE='55000';
   END IF;
 END IF;
 IF TG_OP IN ('INSERT','UPDATE') THEN
   SELECT status INTO v_status FROM inventory_documents
    WHERE tenant_id=NEW.tenant_id AND id=NEW.document_id;
   IF v_status='posted' THEN
     RAISE EXCEPTION 'Lines of posted inventory document are immutable' USING ERRCODE='55000';
   END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$;
CREATE TRIGGER inventory_document_guard
 BEFORE UPDATE OR DELETE ON inventory_documents
 FOR EACH ROW EXECUTE FUNCTION guard_posted_inventory_document();
CREATE TRIGGER inventory_document_line_guard
 BEFORE INSERT OR UPDATE OR DELETE ON inventory_document_lines
 FOR EACH ROW EXECUTE FUNCTION guard_posted_inventory_document();

-- Ledger rows may only be appended for a posted document and its matching line.
-- UPDATE/DELETE remain prohibited by inventory_ledger_immutable above.
CREATE OR REPLACE FUNCTION guard_inventory_ledger_insert()
RETURNS trigger LANGUAGE plpgsql AS $
DECLARE v_status varchar(20); v_line_document uuid; v_line_lot uuid;
BEGIN
 SELECT status INTO v_status
 FROM inventory_documents
 WHERE tenant_id=NEW.tenant_id AND id=NEW.document_id
 FOR KEY SHARE;
 IF v_status IS DISTINCT FROM 'posted' THEN
   RAISE EXCEPTION 'Inventory ledger entries require a posted document' USING ERRCODE='55000';
 END IF;
 SELECT document_id,lot_id INTO v_line_document,v_line_lot
 FROM inventory_document_lines
 WHERE tenant_id=NEW.tenant_id AND id=NEW.document_line_id AND item_id=NEW.item_id;
 IF v_line_document IS DISTINCT FROM NEW.document_id OR v_line_lot IS DISTINCT FROM NEW.lot_id THEN
   RAISE EXCEPTION 'Ledger entry must match its document line, item and lot' USING ERRCODE='55000';
 END IF;
 RETURN NEW;
END;
$;
CREATE TRIGGER inventory_ledger_insert_guard
 BEFORE INSERT ON inventory_ledger_entries
 FOR EACH ROW EXECUTE FUNCTION guard_inventory_ledger_insert();

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
 'inventory_categories','inventory_items','inventory_item_units','inventory_lots','inventory_documents','inventory_document_lines',
 'inventory_ledger_entries','recipes','recipe_versions','recipe_version_items','production_batches','production_batch_events',
 'production_batch_consumptions','sterilizers','sterilization_runs','sterilization_run_batches','mushroom_varieties',
 'inoculation_runs','inoculation_allocations','incubation_records','production_lots','kumbung_placements','production_losses',
 'production_recovery_lots','production_cost_snapshots'
 ] LOOP
   EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
   EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY',t);
   EXECUTE format('CREATE POLICY tenant_isolation ON %I USING (tenant_id=current_tenant_id()) WITH CHECK (tenant_id=current_tenant_id())',t);
 END LOOP;
END $$;

COMMIT;
