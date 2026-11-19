-- Miselium M9 / 0009 qualify invitation acceptance location lookup
-- Fixes PL/pgSQL output-parameter ambiguity without changing invitation semantics.
BEGIN;

CREATE OR REPLACE FUNCTION accept_tenant_invitation(
  p_user_id uuid,
  p_token_hash text
)
RETURNS TABLE(tenant_id uuid, membership_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_invite_accept$
DECLARE
  v_invitation tenant_invitations%ROWTYPE;
  v_membership_id uuid;
  v_existing_status text;
  v_primary_location uuid;
BEGIN
  IF current_app_user_id() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'authenticated user context mismatch' USING ERRCODE = '42501';
  END IF;

  IF p_token_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid invitation token' USING ERRCODE = '22023';
  END IF;

  PERFORM 1 FROM users u
   WHERE u.id = p_user_id AND u.status = 'active'
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active global identity required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_invitation
    FROM tenant_invitations
   WHERE token_hash = p_token_hash
   FOR UPDATE;

  IF NOT FOUND OR v_invitation.status <> 'pending'
     OR v_invitation.expires_at <= now() THEN
    RAISE EXCEPTION 'invitation is invalid or expired' USING ERRCODE = 'P0002';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM user_contact_points cp
     WHERE cp.user_id = p_user_id
       AND cp.contact_type = 'email'
       AND cp.is_verified IS TRUE
       AND lower(cp.normalized_value) = v_invitation.email_normalized
  ) THEN
    RAISE EXCEPTION 'invitation email does not match a verified account email'
      USING ERRCODE = 'P0002';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM tenants t
     WHERE t.id = v_invitation.tenant_id AND t.status = 'active'
  ) THEN
    RAISE EXCEPTION 'tenant is not active' USING ERRCODE = 'P0002';
  END IF;

  SELECT m.id, m.status
    INTO v_membership_id, v_existing_status
    FROM tenant_memberships m
   WHERE m.tenant_id = v_invitation.tenant_id
     AND m.user_id = p_user_id
   FOR UPDATE;

  IF v_membership_id IS NULL THEN
    INSERT INTO tenant_memberships(
      tenant_id, user_id, status, joined_at, invited_by
    )
    VALUES (
      v_invitation.tenant_id, p_user_id, 'active', now(), v_invitation.invited_by
    )
    RETURNING id INTO v_membership_id;
  ELSIF v_existing_status IN ('left', 'invited') THEN
    UPDATE tenant_memberships
       SET status = 'active', joined_at = now(), invited_by = v_invitation.invited_by
     WHERE id = v_membership_id;
  ELSE
    RAISE EXCEPTION 'user already has a non-rejoinable tenant membership'
      USING ERRCODE = '23505';
  END IF;

  DELETE FROM membership_role_assignments AS assignment
   WHERE assignment.tenant_id = v_invitation.tenant_id
     AND assignment.membership_id = v_membership_id;

  INSERT INTO membership_role_assignments(
    tenant_id, membership_id, role_id, assigned_by
  )
  VALUES (
    v_invitation.tenant_id, v_membership_id,
    v_invitation.role_id, v_invitation.invited_by
  );

  DELETE FROM membership_location_scopes AS location_scope
   WHERE location_scope.tenant_id = v_invitation.tenant_id
     AND location_scope.membership_id = v_membership_id;

  SELECT location.id INTO v_primary_location
    FROM locations AS location
   WHERE location.tenant_id = v_invitation.tenant_id AND location.is_primary IS TRUE
     AND location.is_active IS TRUE
   ORDER BY location.created_at
   LIMIT 1;

  IF v_primary_location IS NOT NULL THEN
    INSERT INTO membership_location_scopes(tenant_id, membership_id, location_id)
    VALUES (v_invitation.tenant_id, v_membership_id, v_primary_location)
    ON CONFLICT DO NOTHING;
  END IF;

  UPDATE tenant_invitations
     SET status = 'accepted', accepted_by = p_user_id, accepted_at = now()
   WHERE id = v_invitation.id;

  INSERT INTO platform_audit_events(
    actor_user_id, action, target_type, target_id, metadata
  )
  VALUES (
    p_user_id, 'tenant.invitation.accepted', 'tenant_invitation', v_invitation.id,
    jsonb_build_object(
      'tenant_id', v_invitation.tenant_id,
      'membership_id', v_membership_id,
      'role_id', v_invitation.role_id
    )
  );

  RETURN QUERY SELECT v_invitation.tenant_id, v_membership_id;
END;
$m9_invite_accept$;

REVOKE ALL ON FUNCTION accept_tenant_invitation(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION accept_tenant_invitation(uuid, text) TO miselium_app;

COMMIT;
