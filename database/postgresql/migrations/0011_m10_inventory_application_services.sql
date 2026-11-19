-- Miselium M10 / 0011 Inventory application-service boundaries
-- Adds the runtime privileges and permission vocabulary required by M10 services.
BEGIN;

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
   IF OLD.status='posted' THEN
     IF TG_OP='UPDATE'
        AND NEW.status='reversed'
        AND (to_jsonb(NEW)-'status'-'updated_at')=(to_jsonb(OLD)-'status'-'updated_at') THEN
       RETURN NEW;
     END IF;
     RAISE EXCEPTION 'Posted inventory document is immutable; reverse it instead'
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

-- Restricted runtime role access. RLS remains forced on every tenant-owned table.
GRANT SELECT, INSERT, UPDATE ON inventory_documents TO miselium_app;
GRANT SELECT, INSERT, UPDATE ON inventory_document_lines TO miselium_app;
GRANT SELECT, INSERT ON inventory_ledger_entries TO miselium_app;
GRANT SELECT ON inventory_items, inventory_lots, warehouses TO miselium_app;
GRANT SELECT ON production_batches TO miselium_app;
GRANT SELECT, INSERT ON production_batch_consumptions TO miselium_app;
GRANT INSERT ON tenant_audit_events TO miselium_app;

COMMIT;
