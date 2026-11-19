-- M10 RLS smoke test. Disposable PostgreSQL DB only.
-- Requires non-owner, non-superuser role miselium_app with SELECT, INSERT on inventory_items.
BEGIN;
DO $$
DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); u uuid; item uuid;
BEGIN
 INSERT INTO measurement_units(code,name,dimension)
 VALUES ('M10-'||left(replace(gen_random_uuid()::text,'-',''),10),'Piece','count') RETURNING id INTO u;
 INSERT INTO tenants(code,name) VALUES ('M10A-'||left(replace(a::text,'-',''),8),'Tenant A') RETURNING id INTO a;
 INSERT INTO tenants(code,name) VALUES ('M10B-'||left(replace(b::text,'-',''),8),'Tenant B') RETURNING id INTO b;
 INSERT INTO inventory_items(tenant_id,code,name,item_type,base_unit_id)
 VALUES (a,'ITEM-A','Tenant A item','raw_material',u) RETURNING id INTO item;
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
  RAISE EXCEPTION 'Expected RLS rejection';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
