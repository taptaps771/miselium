-- M9 RBAC/invitation smoke test. Run as a database administrator
-- on a disposable PostgreSQL 16+ database after migrations 0001-0003.
-- Fixtures are rolled back.
BEGIN;

DO $$
DECLARE
  v_tenant uuid := gen_random_uuid();
  v_user uuid := gen_random_uuid();
  v_membership uuid;
  v_member_role uuid;
  v_admin_role uuid;
  v_permission_count integer;
  v_member_write_count integer;
BEGIN
  INSERT INTO users(id, username)
  VALUES (v_user, 'm9-rbac-' || replace(v_user::text, '-', ''));

  INSERT INTO tenants(id, code, name)
  VALUES (
    v_tenant,
    'RBAC-' || left(replace(v_tenant::text, '-', ''), 12),
    'M9 RBAC Smoke Tenant'
  );

  PERFORM ensure_tenant_default_roles(v_tenant);

  INSERT INTO tenant_memberships(tenant_id, user_id, status, joined_at)
  VALUES (v_tenant, v_user, 'active', now())
  RETURNING id INTO v_membership;

  SELECT id INTO v_member_role
    FROM tenant_roles WHERE tenant_id = v_tenant AND code = 'member';
  SELECT id INTO v_admin_role
    FROM tenant_roles WHERE tenant_id = v_tenant AND code = 'admin';

  IF v_member_role IS NULL OR v_admin_role IS NULL THEN
    RAISE EXCEPTION 'Default tenant roles were not created';
  END IF;

  INSERT INTO membership_role_assignments(tenant_id, membership_id, role_id)
  VALUES (v_tenant, v_membership, v_member_role);

  SELECT count(*) INTO v_permission_count
    FROM tenant_role_permissions
   WHERE tenant_id = v_tenant AND role_id = v_admin_role;
  IF v_permission_count <> 9 THEN
    RAISE EXCEPTION 'Expected admin to receive 9 tenant permissions, got %', v_permission_count;
  END IF;

  SELECT count(*) INTO v_member_write_count
    FROM tenant_role_permissions AS rp
    JOIN tenant_permissions AS p ON p.id = rp.permission_id
   WHERE rp.tenant_id = v_tenant
     AND rp.role_id = v_member_role
     AND p.code LIKE '%.manage';
  IF v_member_write_count <> 0 THEN
    RAISE EXCEPTION 'Member role unexpectedly received write permissions';
  END IF;

  INSERT INTO tenant_invitations(
    tenant_id, email_normalized, token_hash, role_id, expires_at
  )
  VALUES (
    v_tenant,
    'new-member@example.invalid',
    encode(digest(gen_random_uuid()::text, 'sha256'), 'hex'),
    v_member_role,
    now() + interval '7 days'
  );

  -- Composite FK must reject a role belonging to another tenant.
  BEGIN
    INSERT INTO tenant_invitations(
      tenant_id, email_normalized, token_hash, role_id, expires_at
    )
    VALUES (
      v_tenant,
      'cross-tenant@example.invalid',
      encode(digest(gen_random_uuid()::text, 'sha256'), 'hex'),
      gen_random_uuid(),
      now() + interval '7 days'
    );
    RAISE EXCEPTION 'Expected tenant-scoped invitation role FK rejection';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END;
$$;

ROLLBACK;
