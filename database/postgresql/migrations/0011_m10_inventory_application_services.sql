-- Miselium M10 / 0011 Inventory application-service boundaries
-- Adds the runtime privileges and permission vocabulary required by M10 services.
BEGIN;

INSERT INTO modules(code, name, description, is_available) VALUES
  ('inventory', 'Inventory', 'Inventory documents, stock ledger and warehouses', true),
  ('production', 'Production', 'Production batches and material consumption', true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO tenant_permissions(code, description) VALUES
  ('tenant.inventory.read', 'View inventory items, stock and documents'),
  ('tenant.inventory.manage', 'Create, post and reverse inventory documents'),
  ('tenant.production.read', 'View production batches and consumption history'),
  ('tenant.production.manage', 'Manage production batch material consumption')
ON CONFLICT (code) DO NOTHING;

-- Existing tenant owner/admin roles receive the new operational permissions.
-- Future tenants receive them through ensure_tenant_default_roles().
INSERT INTO tenant_role_permissions(tenant_id, role_id, permission_id)
SELECT r.tenant_id, r.id, p.id
  FROM tenant_roles AS r
  JOIN tenant_permissions AS p
    ON p.code IN (
      'tenant.inventory.read',
      'tenant.inventory.manage',
      'tenant.production.read',
      'tenant.production.manage'
    )
 WHERE r.code IN ('owner','admin')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Preserve the original posting timestamp when a posted document is reversed.
DO $m10$
DECLARE v_constraint text;
BEGIN
  FOR v_constraint IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid='inventory_documents'::regclass
       AND contype='c'
       AND pg_get_constraintdef(oid) ILIKE '%posted_at%'
  LOOP
    EXECUTE format('ALTER TABLE inventory_documents DROP CONSTRAINT %I', v_constraint);
  END LOOP;
END;
$m10$;
ALTER TABLE inventory_documents
  ADD CONSTRAINT inventory_documents_posted_timestamp_check
  CHECK (
    (status IN ('posted','reversed') AND posted_at IS NOT NULL)
    OR (status NOT IN ('posted','reversed') AND posted_at IS NULL)
  );

-- A posted document can transition to "reversed" exactly once. All other
-- changes to a posted document remain forbidden. Ledger rows stay append-only.
CREATE OR REPLACE FUNCTION guard_posted_inventory_document()
RETURNS trigger LANGUAGE plpgsql AS $m10$
DECLARE v_status varchar(20);
BEGIN
 IF TG_TABLE_NAME='inventory_documents' THEN
   IF OLD.status IN ('posted','reversed') THEN
     IF OLD.status='posted'
        AND TG_OP='UPDATE'
        AND NEW.status='reversed'
        AND (to_jsonb(NEW)-'status'-'updated_at')=(to_jsonb(OLD)-'status'-'updated_at') THEN
       RETURN NEW;
     END IF;
     RAISE EXCEPTION 'Posted or reversed inventory document is immutable'
       USING ERRCODE='55000';
   END IF;
   IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
 END IF;
 IF TG_OP IN ('UPDATE','DELETE') THEN
   SELECT status INTO v_status FROM inventory_documents
    WHERE tenant_id=OLD.tenant_id AND id=OLD.document_id;
   IF v_status IN ('posted','reversed') THEN
     RAISE EXCEPTION 'Lines of posted inventory document are immutable'
       USING ERRCODE='55000';
   END IF;
 END IF;
 IF TG_OP IN ('INSERT','UPDATE') THEN
   SELECT status INTO v_status FROM inventory_documents
    WHERE tenant_id=NEW.tenant_id AND id=NEW.document_id;
   IF v_status IN ('posted','reversed') THEN
     RAISE EXCEPTION 'Lines of posted inventory document are immutable'
       USING ERRCODE='55000';
   END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$m10$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_document_single_reversal
  ON inventory_documents(tenant_id, reversed_document_id)
  WHERE reversed_document_id IS NOT NULL;

-- A consumption record must be derived from an already-posted batch issue.
CREATE OR REPLACE FUNCTION guard_production_batch_consumption_insert()
RETURNS trigger LANGUAGE plpgsql AS $m10$
DECLARE
  v_document_id uuid;
BEGIN
  SELECT document_id INTO v_document_id
    FROM inventory_document_lines
   WHERE tenant_id=NEW.tenant_id AND id=NEW.inventory_document_line_id;
  IF v_document_id IS NULL THEN
    RAISE EXCEPTION 'Production consumption document line was not found'
      USING ERRCODE='23514';
  END IF;

  -- Serialize all consumption inserts for a batch, including direct SQL calls.
  PERFORM pg_advisory_xact_lock(
    hashtextextended(NEW.tenant_id::text || ':production_batch:' || NEW.batch_id::text, 0)
  );

  IF EXISTS (
    SELECT 1
      FROM production_batch_consumptions AS pc
      JOIN inventory_document_lines AS prior_line
        ON prior_line.tenant_id=pc.tenant_id
       AND prior_line.id=pc.inventory_document_line_id
     WHERE pc.tenant_id=NEW.tenant_id
       AND pc.batch_id=NEW.batch_id
       AND prior_line.document_id<>v_document_id
  ) THEN
    RAISE EXCEPTION 'A production batch can only consume one inventory document'
      USING ERRCODE='23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM inventory_document_lines AS l
      JOIN inventory_documents AS d
        ON d.tenant_id=l.tenant_id AND d.id=l.document_id
      JOIN inventory_ledger_entries AS le
        ON le.tenant_id=l.tenant_id
       AND le.document_id=l.document_id
       AND le.document_line_id=l.id
      JOIN production_batches AS b
        ON b.tenant_id=d.tenant_id AND b.id=NEW.batch_id
     WHERE l.tenant_id=NEW.tenant_id
       AND l.id=NEW.inventory_document_line_id
       AND l.item_id=NEW.item_id
       AND l.base_quantity=NEW.consumed_base_quantity
       AND l.currency=NEW.currency
       AND d.document_type='production_consumption'
       AND d.status='posted'
       AND d.source_reference_type='production_batch'
       AND d.source_reference_id=NEW.batch_id
       AND b.status IN ('planned','mixing')
       AND le.quantity_delta<0
       AND abs(le.value_delta)=NEW.material_cost_snapshot
  ) THEN
    RAISE EXCEPTION 'Production consumption must match a posted batch issue ledger line'
      USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$m10$;

CREATE TRIGGER production_batch_consumption_insert_guard
  BEFORE INSERT ON production_batch_consumptions
  FOR EACH ROW EXECUTE FUNCTION guard_production_batch_consumption_insert();
CREATE TRIGGER production_batch_consumptions_immutable
  BEFORE UPDATE OR DELETE ON production_batch_consumptions
  FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

-- Restricted runtime role access. RLS remains forced on every tenant-owned table.
GRANT SELECT, INSERT, UPDATE ON inventory_documents TO miselium_app;
GRANT SELECT, INSERT, UPDATE ON inventory_document_lines TO miselium_app;
GRANT SELECT, INSERT ON inventory_ledger_entries TO miselium_app;
GRANT SELECT ON inventory_items, inventory_item_units, inventory_lots, warehouses TO miselium_app;
GRANT SELECT ON production_batches, modules, tenant_modules TO miselium_app;
GRANT SELECT (default_currency) ON tenants TO miselium_app;
GRANT SELECT, INSERT ON production_batch_consumptions TO miselium_app;
GRANT INSERT ON tenant_audit_events TO miselium_app;

COMMIT;
