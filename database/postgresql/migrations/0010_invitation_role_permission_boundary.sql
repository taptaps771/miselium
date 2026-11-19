-- Miselium M9 / 0010 enforce invitation role permission boundary
-- A tenant member may invite only into roles whose permissions they personally hold.
-- Locks tenant and role rows so concurrent membership/role changes cannot bypass the check.
BEGIN;

CREATE OR REPLACE FUNCTION create_tenant_invitation(
  p_actor_user_id uuid,
  p_tenant_id uuid,
  p_email_normalized text,
  p_token_hash text,
  p_role_id uuid,
  p_expires_at timestamptz
)
RETURNS TABLE(invitation_id uuid, tenant_id uuid, email_normalized varchar(320), expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_invite_create$
DECLARE
  v_id uuid;
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_actor_user_id
     OR current_tenant_id() IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'authenticated tenant context mismatch' USING ERRCODE = '42501';
  END IF;

  PERFORM 1 FROM tenants t
   WHERE t.id = p_tenant_id AND t.status = 'active'
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active tenant not found' USING ERRCODE = 'P0002';
  END IF;

  IF p_email_normalized IS NULL OR length(trim(p_email_normalized)) < 3
     OR length(p_email_normalized) > 320
     OR p_token_hash !~ '^[0-9a-f]{64}$'
     OR p_expires_at <= now()
     OR p_expires_at > now() + interval '30 days' THEN
    RAISE EXCEPTION 'invalid invitation input' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM tenant_memberships m
      JOIN users u ON u.id = m.user_id AND u.status = 'active'
      JOIN membership_role_assignments a
        ON a.tenant_id = m.tenant_id AND a.membership_id = m.id
      JOIN tenant_role_permissions rp
        ON rp.tenant_id = a.tenant_id AND rp.role_id = a.role_id
      JOIN tenant_permissions p ON p.id = rp.permission_id
     WHERE m.tenant_id = p_tenant_id AND m.user_id = p_actor_user_id
       AND m.status = 'active' AND p.code = 'tenant.members.invite'
  ) THEN
    RAISE EXCEPTION 'tenant invitation permission required' USING ERRCODE = '42501';
  END IF;

  -- Serialize against edits to the target role and any role held by the actor.
  PERFORM 1
    FROM tenant_roles r
    JOIN membership_role_assignments a
      ON a.tenant_id = r.tenant_id AND a.role_id = r.id
    JOIN tenant_memberships m
      ON m.tenant_id = a.tenant_id AND m.id = a.membership_id
   WHERE r.tenant_id = p_tenant_id
     AND m.user_id = p_actor_user_id AND m.status = 'active'
   FOR SHARE OF r;

  PERFORM 1 FROM tenant_roles r
   WHERE r.tenant_id = p_tenant_id AND r.id = p_role_id
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'role is unavailable for invitation' USING ERRCODE = '23503';
  END IF;

  -- Re-check after acquiring role locks so a concurrent permission change
  -- cannot revoke invite authority between the first check and this write.
  IF NOT EXISTS (
    SELECT 1
      FROM tenant_memberships m
      JOIN users u ON u.id = m.user_id AND u.status = 'active'
      JOIN membership_role_assignments a
        ON a.tenant_id = m.tenant_id AND a.membership_id = m.id
      JOIN tenant_role_permissions rp
        ON rp.tenant_id = a.tenant_id AND rp.role_id = a.role_id
      JOIN tenant_permissions p ON p.id = rp.permission_id
     WHERE m.tenant_id = p_tenant_id AND m.user_id = p_actor_user_id
       AND m.status = 'active' AND p.code = 'tenant.members.invite'
  ) THEN
    RAISE EXCEPTION 'tenant invitation permission required' USING ERRCODE = '42501';
  END IF;

  -- Invitation must not become a privilege-escalation path. The inviter must
  -- personally hold every permission carried by the role being assigned.
  IF EXISTS (
    SELECT 1
      FROM tenant_role_permissions target_rp
      JOIN tenant_permissions target_p ON target_p.id = target_rp.permission_id
     WHERE target_rp.tenant_id = p_tenant_id
       AND target_rp.role_id = p_role_id
       AND NOT EXISTS (
         SELECT 1
           FROM tenant_memberships actor_m
           JOIN membership_role_assignments actor_a
             ON actor_a.tenant_id = actor_m.tenant_id
            AND actor_a.membership_id = actor_m.id
           JOIN tenant_role_permissions actor_rp
             ON actor_rp.tenant_id = actor_a.tenant_id
            AND actor_rp.role_id = actor_a.role_id
           JOIN tenant_permissions actor_p
             ON actor_p.id = actor_rp.permission_id
          WHERE actor_m.tenant_id = p_tenant_id
            AND actor_m.user_id = p_actor_user_id
            AND actor_m.status = 'active'
            AND actor_p.code = target_p.code
       )
  ) THEN
    RAISE EXCEPTION 'cannot invite a role with permissions not held by actor'
      USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM user_contact_points cp
      JOIN tenant_memberships m ON m.user_id = cp.user_id
     WHERE cp.contact_type = 'email'
       AND cp.is_verified IS TRUE
       AND lower(cp.normalized_value) = lower(trim(p_email_normalized))
       AND m.tenant_id = p_tenant_id
       AND m.status IN ('active', 'suspended')
  ) THEN
    RAISE EXCEPTION 'user already has a non-invitable membership'
      USING ERRCODE = '23505';
  END IF;

  UPDATE tenant_invitations AS invitation
     SET status = 'expired'
   WHERE invitation.tenant_id = p_tenant_id
     AND invitation.email_normalized = lower(trim(p_email_normalized))
     AND invitation.status = 'pending'
     AND invitation.expires_at <= now();

  INSERT INTO tenant_invitations(
    tenant_id, email_normalized, token_hash, role_id, status,
    invited_by, expires_at
  )
  VALUES (
    p_tenant_id, lower(trim(p_email_normalized)), p_token_hash, p_role_id,
    'pending', p_actor_user_id, p_expires_at
  )
  RETURNING id INTO v_id;

  INSERT INTO platform_audit_events(
    actor_user_id, action, target_type, target_id, metadata
  )
  VALUES (
    p_actor_user_id, 'tenant.invitation.created', 'tenant_invitation', v_id,
    jsonb_build_object(
      'tenant_id', p_tenant_id,
      'email', lower(trim(p_email_normalized)),
      'role_id', p_role_id
    )
  );

  RETURN QUERY
    SELECT i.id, i.tenant_id, i.email_normalized, i.expires_at
      FROM tenant_invitations i WHERE i.id = v_id;
END;
$m9_invite_create$;

REVOKE ALL ON FUNCTION create_tenant_invitation(uuid, uuid, text, text, uuid, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_tenant_invitation(uuid, uuid, text, text, uuid, timestamptz) TO miselium_app;

COMMIT;
