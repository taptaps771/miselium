-- Miselium M9 / 0008 Tenant role and permission administration
-- Custom tenant roles only. System roles remain immutable through this API.
BEGIN;

CREATE OR REPLACE FUNCTION list_tenant_roles(p_actor_user_id uuid, p_tenant_id uuid)
RETURNS TABLE(
  role_id uuid,
  role_code varchar(60),
  role_name varchar(120),
  is_system boolean,
  permission_codes text[],
  member_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_roles_list$
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_actor_user_id
     OR current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'authenticated tenant context mismatch' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1
      FROM tenant_memberships m
      JOIN membership_role_assignments a ON a.tenant_id=m.tenant_id AND a.membership_id=m.id
      JOIN tenant_role_permissions rp ON rp.tenant_id=a.tenant_id AND rp.role_id=a.role_id
      JOIN tenant_permissions p ON p.id=rp.permission_id
     WHERE m.tenant_id=p_tenant_id AND m.user_id=p_actor_user_id
       AND m.status='active' AND p.code='tenant.roles.read'
  ) THEN
    RAISE EXCEPTION 'tenant role read permission required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
    SELECT r.id, r.code, r.name, r.is_system,
           COALESCE(array_agg(DISTINCT p.code::text) FILTER (WHERE p.code IS NOT NULL), ARRAY[]::text[]),
           count(DISTINCT mra.membership_id)
      FROM tenant_roles r
      LEFT JOIN tenant_role_permissions rp ON rp.tenant_id=r.tenant_id AND rp.role_id=r.id
      LEFT JOIN tenant_permissions p ON p.id=rp.permission_id
      LEFT JOIN membership_role_assignments mra ON mra.tenant_id=r.tenant_id AND mra.role_id=r.id
     WHERE r.tenant_id=p_tenant_id
     GROUP BY r.id, r.code, r.name, r.is_system
     ORDER BY r.is_system DESC, r.name, r.code;
END;
$m9_roles_list$;

CREATE OR REPLACE FUNCTION list_tenant_permission_catalog(p_actor_user_id uuid, p_tenant_id uuid)
RETURNS TABLE(permission_code varchar(140), description text, actor_can_grant boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_permission_catalog$
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_actor_user_id
     OR current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'authenticated tenant context mismatch' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1
      FROM tenant_memberships m
      JOIN membership_role_assignments a ON a.tenant_id=m.tenant_id AND a.membership_id=m.id
      JOIN tenant_role_permissions rp ON rp.tenant_id=a.tenant_id AND rp.role_id=a.role_id
      JOIN tenant_permissions p ON p.id=rp.permission_id
     WHERE m.tenant_id=p_tenant_id AND m.user_id=p_actor_user_id
       AND m.status='active' AND p.code='tenant.roles.read'
  ) THEN
    RAISE EXCEPTION 'tenant role read permission required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
    SELECT p.code, p.description,
           EXISTS (
             SELECT 1
               FROM tenant_memberships am
               JOIN membership_role_assignments aa ON aa.tenant_id=am.tenant_id AND aa.membership_id=am.id
               JOIN tenant_role_permissions arp ON arp.tenant_id=aa.tenant_id AND arp.role_id=aa.role_id
               JOIN tenant_permissions ap ON ap.id=arp.permission_id
              WHERE am.tenant_id=p_tenant_id AND am.user_id=p_actor_user_id
                AND am.status='active' AND ap.code=p.code
           )
      FROM tenant_permissions p
     ORDER BY p.code;
END;
$m9_permission_catalog$;

CREATE OR REPLACE FUNCTION create_tenant_role(
  p_actor_user_id uuid,
  p_tenant_id uuid,
  p_role_code text,
  p_role_name text,
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_role_create$
DECLARE
  v_role_id uuid;
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_actor_user_id
     OR current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'authenticated tenant context mismatch' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM tenant_memberships m
    JOIN membership_role_assignments a ON a.tenant_id=m.tenant_id AND a.membership_id=m.id
    JOIN tenant_role_permissions rp ON rp.tenant_id=a.tenant_id AND rp.role_id=a.role_id
    JOIN tenant_permissions p ON p.id=rp.permission_id
    WHERE m.tenant_id=p_tenant_id AND m.user_id=p_actor_user_id
      AND m.status='active' AND p.code='tenant.roles.manage'
  ) THEN
    RAISE EXCEPTION 'tenant role management permission required' USING ERRCODE='42501';
  END IF;
  IF p_role_code IS NULL OR p_role_code !~ '^[a-z][a-z0-9_-]{1,59}$'
     OR p_role_code IN ('owner','admin','member')
     OR p_role_name IS NULL OR length(trim(p_role_name))=0 OR length(p_role_name)>120 THEN
    RAISE EXCEPTION 'invalid custom role code or name' USING ERRCODE='22023';
  END IF;

  INSERT INTO tenant_roles(tenant_id,code,name,is_system)
  VALUES(p_tenant_id,p_role_code,trim(p_role_name),false)
  RETURNING id INTO v_role_id;

  INSERT INTO tenant_audit_events(tenant_id,actor_user_id,action,entity_type,entity_id,reason,after_data)
  VALUES(p_tenant_id,p_actor_user_id,'tenant.role.created','tenant_role',v_role_id,
         nullif(trim(p_reason),''),jsonb_build_object('code',p_role_code,'name',trim(p_role_name),'permissions',ARRAY[]::text[]));
  RETURN v_role_id;
END;
$m9_role_create$;

CREATE OR REPLACE FUNCTION set_tenant_role_permissions(
  p_actor_user_id uuid,
  p_tenant_id uuid,
  p_role_id uuid,
  p_permission_codes text[],
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_role_permissions$
DECLARE
  v_role_code text;
  v_before text[];
  v_after text[];
  v_requested_count integer;
  v_known_count integer;
  v_grantable_count integer;
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_actor_user_id
     OR current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'authenticated tenant context mismatch' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM tenant_memberships m
    JOIN membership_role_assignments a ON a.tenant_id=m.tenant_id AND a.membership_id=m.id
    JOIN tenant_role_permissions rp ON rp.tenant_id=a.tenant_id AND rp.role_id=a.role_id
    JOIN tenant_permissions p ON p.id=rp.permission_id
    WHERE m.tenant_id=p_tenant_id AND m.user_id=p_actor_user_id
      AND m.status='active' AND p.code='tenant.roles.manage'
  ) THEN
    RAISE EXCEPTION 'tenant role management permission required' USING ERRCODE='42501';
  END IF;

  SELECT code INTO v_role_code
    FROM tenant_roles WHERE tenant_id=p_tenant_id AND id=p_role_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tenant role not found' USING ERRCODE='P0002';
  END IF;
  IF EXISTS (SELECT 1 FROM tenant_roles WHERE tenant_id=p_tenant_id AND id=p_role_id AND is_system) THEN
    RAISE EXCEPTION 'system roles are immutable' USING ERRCODE='22023';
  END IF;
  IF p_permission_codes IS NULL OR cardinality(p_permission_codes)>300 THEN
    RAISE EXCEPTION 'invalid permission list' USING ERRCODE='22023';
  END IF;

  SELECT COALESCE(array_agg(p.code::text ORDER BY p.code),ARRAY[]::text[])
    INTO v_before
    FROM tenant_role_permissions rp
    JOIN tenant_permissions p ON p.id=rp.permission_id
   WHERE rp.tenant_id=p_tenant_id AND rp.role_id=p_role_id;

  SELECT count(DISTINCT requested.code) INTO v_requested_count FROM unnest(p_permission_codes) AS requested(code);
  SELECT count(DISTINCT p.code) INTO v_known_count
    FROM tenant_permissions p WHERE p.code=ANY(p_permission_codes);
  SELECT count(DISTINCT p.code) INTO v_grantable_count
    FROM tenant_permissions p
   WHERE p.code=ANY(p_permission_codes)
     AND EXISTS (
       SELECT 1 FROM tenant_memberships am
       JOIN membership_role_assignments aa ON aa.tenant_id=am.tenant_id AND aa.membership_id=am.id
       JOIN tenant_role_permissions arp ON arp.tenant_id=aa.tenant_id AND arp.role_id=aa.role_id
       JOIN tenant_permissions ap ON ap.id=arp.permission_id
       WHERE am.tenant_id=p_tenant_id AND am.user_id=p_actor_user_id
         AND am.status='active' AND ap.code=p.code
     );
  IF v_known_count<>v_requested_count THEN
    RAISE EXCEPTION 'unknown or duplicate permission code' USING ERRCODE='22023';
  END IF;
  IF v_grantable_count<>v_requested_count THEN
    RAISE EXCEPTION 'cannot grant permissions not held by actor' USING ERRCODE='42501';
  END IF;

  DELETE FROM tenant_role_permissions WHERE tenant_id=p_tenant_id AND role_id=p_role_id;
  INSERT INTO tenant_role_permissions(tenant_id,role_id,permission_id)
  SELECT p_tenant_id,p_role_id,p.id
    FROM tenant_permissions p WHERE p.code=ANY(p_permission_codes);
  SELECT COALESCE(array_agg(requested.code ORDER BY requested.code),ARRAY[]::text[]) INTO v_after
    FROM unnest(p_permission_codes) AS requested(code);

  INSERT INTO tenant_audit_events(tenant_id,actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  VALUES(p_tenant_id,p_actor_user_id,'tenant.role.permissions_changed','tenant_role',p_role_id,
         nullif(trim(p_reason),''),jsonb_build_object('permissions',v_before),
         jsonb_build_object('permissions',v_after));
END;
$m9_role_permissions$;

REVOKE ALL ON FUNCTION list_tenant_roles(uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION list_tenant_permission_catalog(uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION create_tenant_role(uuid,uuid,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION set_tenant_role_permissions(uuid,uuid,uuid,text[],text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION list_tenant_roles(uuid,uuid) TO miselium_app;
GRANT EXECUTE ON FUNCTION list_tenant_permission_catalog(uuid,uuid) TO miselium_app;
GRANT EXECUTE ON FUNCTION create_tenant_role(uuid,uuid,text,text,text) TO miselium_app;
GRANT EXECUTE ON FUNCTION set_tenant_role_permissions(uuid,uuid,uuid,text[],text) TO miselium_app;

COMMIT;
