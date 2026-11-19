-- Miselium M9 / 0007 Tenant membership administration
-- PostgreSQL 16+. All membership mutations are permission-checked, tenant-scoped,
-- serialized per tenant, and audited. Global user identities are never deleted.
BEGIN;

CREATE OR REPLACE FUNCTION list_tenant_members(
  p_actor_user_id uuid,
  p_tenant_id uuid
)
RETURNS TABLE(
  membership_id uuid,
  user_id uuid,
  display_name varchar(160),
  email varchar(320),
  membership_status varchar(20),
  joined_at timestamptz,
  role_codes text[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_members_list$
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_actor_user_id
     OR current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'authenticated tenant context mismatch' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM tenant_memberships m
      JOIN users u ON u.id = m.user_id AND u.status = 'active'
      JOIN tenants t ON t.id = m.tenant_id AND t.status = 'active'
      JOIN membership_role_assignments a
        ON a.tenant_id = m.tenant_id AND a.membership_id = m.id
      JOIN tenant_role_permissions rp
        ON rp.tenant_id = a.tenant_id AND rp.role_id = a.role_id
      JOIN tenant_permissions p ON p.id = rp.permission_id
     WHERE m.tenant_id = p_tenant_id AND m.user_id = p_actor_user_id
       AND m.status = 'active' AND p.code = 'tenant.members.read'
  ) THEN
    RAISE EXCEPTION 'tenant membership read permission required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT m.id, u.id, up.display_name, cp.normalized_value, m.status, m.joined_at,
           COALESCE(array_agg(DISTINCT r.code::text) FILTER (WHERE r.code IS NOT NULL), ARRAY[]::text[])
      FROM tenant_memberships m
      JOIN users u ON u.id = m.user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      LEFT JOIN user_contact_points cp
        ON cp.user_id = u.id AND cp.contact_type = 'email' AND cp.is_primary IS TRUE
      LEFT JOIN membership_role_assignments a
        ON a.tenant_id = m.tenant_id AND a.membership_id = m.id
      LEFT JOIN tenant_roles r
        ON r.tenant_id = a.tenant_id AND r.id = a.role_id
     WHERE m.tenant_id = p_tenant_id
     GROUP BY m.id, u.id, up.display_name, cp.normalized_value, m.created_at
     ORDER BY up.display_name NULLS LAST, cp.normalized_value NULLS LAST, m.created_at;
END;
$m9_members_list$;

CREATE OR REPLACE FUNCTION set_tenant_member_role(
  p_actor_user_id uuid,
  p_tenant_id uuid,
  p_membership_id uuid,
  p_role_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_member_role$
DECLARE
  v_old_roles text[];
  v_new_role_code text;
  v_before jsonb;
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_actor_user_id
     OR current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'authenticated tenant context mismatch' USING ERRCODE = '42501';
  END IF;
  PERFORM 1 FROM tenants WHERE id = p_tenant_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active tenant not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM tenant_memberships m
    JOIN membership_role_assignments a ON a.tenant_id=m.tenant_id AND a.membership_id=m.id
    JOIN tenant_role_permissions rp ON rp.tenant_id=a.tenant_id AND rp.role_id=a.role_id
    JOIN tenant_permissions p ON p.id=rp.permission_id
    WHERE m.tenant_id=p_tenant_id AND m.user_id=p_actor_user_id
      AND m.status='active' AND p.code='tenant.members.manage'
  ) THEN
    RAISE EXCEPTION 'tenant membership management permission required' USING ERRCODE = '42501';
  END IF;

  SELECT array_agg(r.code ORDER BY r.code) INTO v_old_roles
    FROM membership_role_assignments a
    JOIN tenant_roles r ON r.tenant_id=a.tenant_id AND r.id=a.role_id
   WHERE a.tenant_id=p_tenant_id AND a.membership_id=p_membership_id;

  SELECT code INTO v_new_role_code FROM tenant_roles
   WHERE tenant_id=p_tenant_id AND id=p_role_id;
  IF v_new_role_code IS NULL OR v_new_role_code='owner' THEN
    RAISE EXCEPTION 'requested role is not assignable' USING ERRCODE = '22023';
  END IF;

  -- A manager may not grant permissions they do not personally hold.
  IF EXISTS (
    SELECT 1
      FROM tenant_role_permissions target_rp
      JOIN tenant_permissions target_p ON target_p.id=target_rp.permission_id
     WHERE target_rp.tenant_id=p_tenant_id AND target_rp.role_id=p_role_id
       AND NOT EXISTS (
         SELECT 1
           FROM tenant_memberships actor_m
           JOIN membership_role_assignments actor_a
             ON actor_a.tenant_id=actor_m.tenant_id AND actor_a.membership_id=actor_m.id
           JOIN tenant_role_permissions actor_rp
             ON actor_rp.tenant_id=actor_a.tenant_id AND actor_rp.role_id=actor_a.role_id
           JOIN tenant_permissions actor_p ON actor_p.id=actor_rp.permission_id
          WHERE actor_m.tenant_id=p_tenant_id AND actor_m.user_id=p_actor_user_id
            AND actor_m.status='active' AND actor_p.code=target_p.code
       )
  ) THEN
    RAISE EXCEPTION 'cannot grant permissions not held by actor' USING ERRCODE = '42501';
  END IF;

  PERFORM 1 FROM tenant_memberships
   WHERE tenant_id=p_tenant_id AND id=p_membership_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tenant membership not found' USING ERRCODE = 'P0002';
  END IF;

  IF 'owner'=ANY(COALESCE(v_old_roles, ARRAY[]::text[])) THEN
    IF (SELECT count(DISTINCT m.id)
          FROM tenant_memberships m
          JOIN membership_role_assignments a ON a.tenant_id=m.tenant_id AND a.membership_id=m.id
          JOIN tenant_roles r ON r.tenant_id=a.tenant_id AND r.id=a.role_id AND r.code='owner'
         WHERE m.tenant_id=p_tenant_id AND m.status='active') <= 1 THEN
      RAISE EXCEPTION 'last active owner cannot be demoted' USING ERRCODE = '23514';
    END IF;
  END IF;

  v_before := jsonb_build_object('roles', COALESCE(v_old_roles, ARRAY[]::text[]));
  DELETE FROM membership_role_assignments
   WHERE tenant_id=p_tenant_id AND membership_id=p_membership_id;
  INSERT INTO membership_role_assignments(tenant_id,membership_id,role_id,assigned_by)
  VALUES(p_tenant_id,p_membership_id,p_role_id,p_actor_user_id);

  INSERT INTO tenant_audit_events(tenant_id,actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  VALUES(p_tenant_id,p_actor_user_id,'tenant.member.role_changed','tenant_membership',p_membership_id,
         nullif(trim(p_reason),''),v_before,jsonb_build_object('roles',jsonb_build_array(v_new_role_code)));
END;
$m9_member_role$;

CREATE OR REPLACE FUNCTION transition_tenant_member(
  p_actor_user_id uuid,
  p_tenant_id uuid,
  p_membership_id uuid,
  p_action text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_member_transition$
DECLARE
  v_status text;
  v_is_owner boolean;
  v_owner_count integer;
  v_new_status text;
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_actor_user_id
     OR current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'authenticated tenant context mismatch' USING ERRCODE = '42501';
  END IF;
  IF p_action NOT IN ('suspend','reactivate','remove') THEN
    RAISE EXCEPTION 'unsupported membership action' USING ERRCODE = '22023';
  END IF;
  PERFORM 1 FROM tenants WHERE id=p_tenant_id AND status='active' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active tenant not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM tenant_memberships m
    JOIN membership_role_assignments a ON a.tenant_id=m.tenant_id AND a.membership_id=m.id
    JOIN tenant_role_permissions rp ON rp.tenant_id=a.tenant_id AND rp.role_id=a.role_id
    JOIN tenant_permissions p ON p.id=rp.permission_id
    WHERE m.tenant_id=p_tenant_id AND m.user_id=p_actor_user_id
      AND m.status='active' AND p.code='tenant.members.manage'
  ) THEN
    RAISE EXCEPTION 'tenant membership management permission required' USING ERRCODE = '42501';
  END IF;

  SELECT m.status,
         EXISTS(SELECT 1 FROM membership_role_assignments a
                JOIN tenant_roles r ON r.tenant_id=a.tenant_id AND r.id=a.role_id
                WHERE a.tenant_id=m.tenant_id AND a.membership_id=m.id AND r.code='owner')
    INTO v_status,v_is_owner
    FROM tenant_memberships m
   WHERE m.tenant_id=p_tenant_id AND m.id=p_membership_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tenant membership not found' USING ERRCODE = 'P0002';
  END IF;

  IF p_action='suspend' AND v_status='active' THEN
    v_new_status := 'suspended';
  ELSIF p_action='reactivate' AND v_status='suspended' THEN
    v_new_status := 'active';
  ELSIF p_action='remove' AND v_status IN ('active','suspended') THEN
    v_new_status := 'left';
  ELSE
    RAISE EXCEPTION 'membership status does not allow this action' USING ERRCODE = '22023';
  END IF;

  IF v_is_owner AND v_status='active' AND v_new_status <> 'active' THEN
    SELECT count(DISTINCT m.id) INTO v_owner_count
      FROM tenant_memberships m
      JOIN membership_role_assignments a ON a.tenant_id=m.tenant_id AND a.membership_id=m.id
      JOIN tenant_roles r ON r.tenant_id=a.tenant_id AND r.id=a.role_id AND r.code='owner'
     WHERE m.tenant_id=p_tenant_id AND m.status='active';
    IF v_owner_count <= 1 THEN
      RAISE EXCEPTION 'last active owner cannot be suspended or removed' USING ERRCODE = '23514';
    END IF;
  END IF;

  UPDATE tenant_memberships SET status=v_new_status
   WHERE tenant_id=p_tenant_id AND id=p_membership_id;
  INSERT INTO tenant_audit_events(tenant_id,actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  VALUES(p_tenant_id,p_actor_user_id,'tenant.member.'||p_action,'tenant_membership',p_membership_id,
         nullif(trim(p_reason),''),jsonb_build_object('status',v_status),jsonb_build_object('status',v_new_status));
END;
$m9_member_transition$;

REVOKE ALL ON FUNCTION list_tenant_members(uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION set_tenant_member_role(uuid,uuid,uuid,uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION transition_tenant_member(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION list_tenant_members(uuid,uuid) TO miselium_app;
GRANT EXECUTE ON FUNCTION set_tenant_member_role(uuid,uuid,uuid,uuid,text) TO miselium_app;
GRANT EXECUTE ON FUNCTION transition_tenant_member(uuid,uuid,uuid,text,text) TO miselium_app;

COMMIT;
