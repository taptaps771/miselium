-- M9 foundation smoke test. Run as a database administrator on a disposable DB.
-- Requires a pre-created non-owner, non-superuser role: miselium_app.
-- Grant this role SELECT, INSERT on locations before running.
-- Fixtures are rolled back; RLS assertions execute under the runtime role.
BEGIN;

DO $$
DECLARE
  tenant_a uuid := gen_random_uuid();
  tenant_b uuid := gen_random_uuid();
  user_a uuid := gen_random_uuid();
  location_a uuid;
  location_b uuid;
BEGIN
  INSERT INTO users(id, username) VALUES (user_a, 'm9-smoke-' || replace(user_a::text,'-',''));
  INSERT INTO tenants(id, code, name) VALUES
    (tenant_a, 'M9A-' || left(replace(tenant_a::text,'-',''),8), 'M9 Tenant A'),
    (tenant_b, 'M9B-' || left(replace(tenant_b::text,'-',''),8), 'M9 Tenant B');

  INSERT INTO locations(tenant_id, code, name, is_primary)
  VALUES (tenant_a, 'MAIN', 'A Main', true) RETURNING id INTO location_a;
  INSERT INTO locations(tenant_id, code, name, is_primary)
  VALUES (tenant_b, 'MAIN', 'B Main', true) RETURNING id INTO location_b;

  INSERT INTO warehouses(tenant_id, location_id, code, name)
  VALUES (tenant_a, location_a, 'WH-A', 'Warehouse A');

  BEGIN
    INSERT INTO warehouses(tenant_id, location_id, code, name)
    VALUES (tenant_a, location_b, 'BAD', 'Cross tenant');
    RAISE EXCEPTION 'Expected cross-tenant composite FK rejection';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  PERFORM set_config('m9.tenant_a', tenant_a::text, true);
  PERFORM set_config('m9.tenant_b', tenant_b::text, true);
END $$;

SET LOCAL ROLE miselium_app;
SELECT set_config('app.tenant_id', current_setting('m9.tenant_a'), true);

DO $$
DECLARE
  visible_count integer;
  tenant_b uuid := current_setting('m9.tenant_b')::uuid;
BEGIN
  SELECT count(*) INTO visible_count FROM locations;
  IF visible_count <> 1 THEN
    RAISE EXCEPTION 'Expected one visible location for tenant A, got %', visible_count;
  END IF;

  BEGIN
    INSERT INTO locations(tenant_id, code, name)
    VALUES (tenant_b, 'INTRUDE', 'Should fail');
    RAISE EXCEPTION 'Expected RLS rejection for cross-tenant insert';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END $$;

ROLLBACK;
