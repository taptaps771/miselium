-- M10 PostgreSQL 16 smoke + invariant test. Disposable database only.
-- Run as a database administrator after M9 + M10 migrations and role setup.
BEGIN;
DO $$
DECLARE
 a uuid; b uuid; u uuid; item uuid; loc uuid; wh uuid; doc uuid; line_id uuid;
BEGIN
 INSERT INTO measurement_units(code,name,dimension)
 VALUES ('M10-'||left(replace(gen_random_uuid()::text,'-',''),10),'Piece','count')
 RETURNING id INTO u;
 INSERT INTO tenants(code,name)
 VALUES ('M10A-'||left(replace(gen_random_uuid()::text,'-',''),8),'Tenant A')
 RETURNING id INTO a;
 INSERT INTO tenants(code,name)
 VALUES ('M10B-'||left(replace(gen_random_uuid()::text,'-',''),8),'Tenant B')
 RETURNING id INTO b;
 INSERT INTO inventory_items(tenant_id,code,name,item_type,base_unit_id)
 VALUES (a,'ITEM-A','Tenant A item','raw_material',u) RETURNING id INTO item;
 INSERT INTO locations(tenant_id,code,name) VALUES (a,'LOC-A','Location A') RETURNING id INTO loc;
 INSERT INTO warehouses(tenant_id,location_id,code,name)
 VALUES (a,loc,'WH-A','Warehouse A') RETURNING id INTO wh;
 INSERT INTO inventory_documents(tenant_id,document_no,document_type,destination_warehouse_id)
 VALUES (a,'M10-RECEIPT','receipt',wh) RETURNING id INTO doc;
 INSERT INTO inventory_document_lines(
   tenant_id,document_id,line_no,item_id,item_code_snapshot,item_name_snapshot,
   quantity,unit_id,unit_name_snapshot,conversion_to_base_snapshot,base_quantity,
   unit_cost_snapshot,currency,line_value_snapshot
 ) VALUES (a,doc,1,item,'ITEM-A','Tenant A item',1,u,'Piece',1,1,10,'IDR',10)
 RETURNING id INTO line_id;

 -- Draft documents must not be able to write stock ledger entries.
 BEGIN
   INSERT INTO inventory_ledger_entries(
     tenant_id,document_id,document_line_id,warehouse_id,item_id,
     quantity_delta,value_delta,currency,unit_cost_snapshot,occurred_at
   ) VALUES (a,doc,line_id,wh,item,1,10,'IDR',10,now());
   RAISE EXCEPTION 'Expected draft-ledger insert to be rejected';
 EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
 END;

 UPDATE inventory_documents SET status='posted',posted_at=now() WHERE tenant_id=a AND id=doc;
 INSERT INTO inventory_ledger_entries(
   tenant_id,document_id,document_line_id,warehouse_id,item_id,
   quantity_delta,value_delta,currency,unit_cost_snapshot,occurred_at
 ) VALUES (a,doc,line_id,wh,item,1,10,'IDR',10,now());

 -- A posted document cannot accept new lines or mutate existing ledger history.
 BEGIN
   INSERT INTO inventory_document_lines(
     tenant_id,document_id,line_no,item_id,item_code_snapshot,item_name_snapshot,
     quantity,unit_id,unit_name_snapshot,conversion_to_base_snapshot,base_quantity
   ) VALUES (a,doc,2,item,'ITEM-A','Tenant A item',1,u,'Piece',1,1);
   RAISE EXCEPTION 'Expected posted-document line insert to be rejected';
 EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
 END;
 BEGIN
   UPDATE inventory_ledger_entries SET quantity_delta=2
    WHERE tenant_id=a AND document_id=doc;
   RAISE EXCEPTION 'Expected ledger update to be rejected';
 EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
 END;

 PERFORM set_config('m10.tenant_a',a::text,true);
 PERFORM set_config('m10.tenant_b',b::text,true);
END $$;

SET LOCAL ROLE miselium_app;
SELECT set_config('app.tenant_id',current_setting('m10.tenant_a'),true);
DO $$
DECLARE n integer; b uuid:=current_setting('m10.tenant_b')::uuid; u uuid;
BEGIN
 SELECT count(*) INTO n FROM inventory_items;
 IF n<>1 THEN RAISE EXCEPTION 'Expected one tenant A item, got %',n; END IF;
 SELECT base_unit_id INTO u FROM inventory_items LIMIT 1;
 BEGIN
   INSERT INTO inventory_items(tenant_id,code,name,item_type,base_unit_id)
   VALUES (b,'INTRUDE','Cross tenant','raw_material',u);
   RAISE EXCEPTION 'Expected cross-tenant RLS rejection';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
