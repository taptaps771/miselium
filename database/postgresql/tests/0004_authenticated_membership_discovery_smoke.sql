-- M9 authenticated membership discovery smoke test.
-- Run after migrations 0001-0004 on a disposable PostgreSQL database.
-- Requires miselium_app to have SELECT on tenant_memberships.
BEGIN;

DO $$
DECLARE
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_tenant_a uuid := gen_random_uuid();
  v_tenant_b uuid := gen_random_uuid();
BEGIN
  INSERT INTO users(id, username) VALUES
    (v_user_a, 'm9-user-a-' || replace(v_user_a::text, '-', '')),
    (v_user_b, 'm9-user-b-' || replace(v_user_b::text, '-', ''));

  INSERT INTO tenants(id, code, name, status, approved_at, approval_reason) VALUES
    (v_tenant_a, 'M9UA-' || left(replace(v_tenant_a::text, '-', ''), 8), 'User A Tenant A', 'active', now(), 'CI fixture'),
    (v_tenant_b, 'M9UB-' || left(replace(v_tenant_b::text, '-', ''), 8), 'User A Tenant B', 'active', now(), 'CI fixture');

  INSERT INTO tenant_memberships(tenant_id, user_id, status, joined_at) VALUES
    (v_tenant_a, v_user_a, 'active', now()),
    (v_tenant_b, v_user_a, 'active', now()),
    (v_tenant_a, v_user_b, 'active', now());

  PERFORM set_config('m9.user_a', v_user_a::text, true);
  PERFORM set_config('m9.user_b', v_user_b::text, true);
END $$;

SET LOCAL ROLE miselium_app;
SELECT set_config('app.user_id', current_setting('m9.user_a'), true);

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
    FROM tenant_memberships
   WHERE status = 'active';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'User A should discover exactly two active memberships, got %', v_count;
  END IF;

  PERFORM set_config('app.user_id', current_setting('m9.user_b'), true);
  SELECT count(*) INTO v_count
    FROM tenant_memberships
   WHERE status = 'active';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'User B should discover exactly one active membership, got %', v_count;
  END IF;

  PERFORM set_config('app.user_id', '', true);
  SELECT count(*) INTO v_count FROM tenant_memberships;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'No authenticated user context must reveal no memberships, got %', v_count;
  END IF;
END $$;

ROLLBACK;
