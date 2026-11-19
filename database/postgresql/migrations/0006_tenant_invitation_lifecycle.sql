-- Miselium M9 / 0006 Tenant invitation acceptance and membership lifecycle
-- PostgreSQL 16+. Additive; preserves existing invitations and memberships.
BEGIN;

ALTER TABLE tenant_invitations
  ADD COLUMN accepted_at timestamptz,
  ADD COLUMN revoked_at timestamptz;

-- Timestamp columns are optional for historical terminal records. New
-- transitions performed by these functions always populate the timestamps.
ALTER TABLE tenant_invitations
  ADD CONSTRAINT ck_tenant_invitation_state_timestamps CHECK (
    (accepted_at IS NULL OR status = 'accepted')
    AND (revoked_at IS NULL OR status = 'revoked')
  );

CREATE UNIQUE INDEX uq_tenant_invitation_pending_email
  ON tenant_invitations(tenant_id, email_normalized)
  WHERE status = 'pending';

CREATE INDEX ix_tenant_invitations_pending_expiry
  ON tenant_invitations(expires_at)
  WHERE status = 'pending';

-- All invitation writes pass through narrowly scoped functions. The runtime
-- role cannot insert arbitrary role assignments or update invitation state.
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
  IF p_email_normalized IS NULL OR length(trim(p_email_normalized)) < 3
     OR length(p_email_normalized) > 320
     OR p_token_hash !~ '^[0-9a-f]{64}$'
     OR p_expires_at <= now()
     OR p_expires_at > now() + interval '30 days' THEN
    RAISE EXCEPTION 'invalid invitation input' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM tenants t
      JOIN tenant_memberships m ON m.tenant_id = t.id
      JOIN membership_role_assignments a
        ON a.tenant_id = m.tenant_id AND a.membership_id = m.id
      JOIN tenant_role_permissions rp
        ON rp.tenant_id = a.tenant_id AND rp.role_id = a.role_id
      JOIN tenant_permissions p ON p.id = rp.permission_id
     WHERE t.id = p_tenant_id AND t.status = 'active'
       AND m.user_id = p_actor_user_id AND m.status = 'active'
       AND p.code = 'tenant.members.invite'
  ) THEN
    RAISE EXCEPTION 'tenant invitation permission required' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM tenant_roles r
     WHERE r.tenant_id = p_tenant_id AND r.id = p_role_id
       AND (r.is_system IS FALSE OR r.code = 'member')
  ) THEN
    RAISE EXCEPTION 'role is unavailable for invitation' USING ERRCODE = '23503';
  END IF;

  UPDATE tenant_invitations
     SET status = 'expired'
   WHERE tenant_id = p_tenant_id
     AND email_normalized = lower(trim(p_email_normalized))
     AND status = 'pending'
     AND expires_at <= now();

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

CREATE OR REPLACE FUNCTION list_tenant_invitations(
  p_actor_user_id uuid,
  p_tenant_id uuid
)
RETURNS TABLE(
  invitation_id uuid,
  email_normalized varchar(320),
  status varchar(20),
  role_code varchar(60),
  expires_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_invite_list$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM tenant_memberships m
      JOIN membership_role_assignments a
        ON a.tenant_id = m.tenant_id AND a.membership_id = m.id
      JOIN tenant_role_permissions rp
        ON rp.tenant_id = a.tenant_id AND rp.role_id = a.role_id
      JOIN tenant_permissions p ON p.id = rp.permission_id
     WHERE m.tenant_id = p_tenant_id
       AND m.user_id = p_actor_user_id AND m.status = 'active'
       AND p.code IN ('tenant.members.invite', 'tenant.members.read')
  ) THEN
    RAISE EXCEPTION 'tenant membership permission required' USING ERRCODE = '42501';
  END IF;

  UPDATE tenant_invitations
     SET status = 'expired'
   WHERE tenant_id = p_tenant_id
     AND status = 'pending' AND expires_at <= now();

  RETURN QUERY
    SELECT i.id, i.email_normalized, i.status, r.code, i.expires_at, i.created_at
      FROM tenant_invitations i
      JOIN tenant_roles r
        ON r.tenant_id = i.tenant_id AND r.id = i.role_id
     WHERE i.tenant_id = p_tenant_id
     ORDER BY i.created_at DESC;
END;
$m9_invite_list$;

CREATE OR REPLACE FUNCTION revoke_tenant_invitation(
  p_actor_user_id uuid,
  p_tenant_id uuid,
  p_invitation_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $m9_invite_revoke$
DECLARE
  v_email text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM tenant_memberships m
      JOIN membership_role_assignments a
        ON a.tenant_id = m.tenant_id AND a.membership_id = m.id
      JOIN tenant_role_permissions rp
        ON rp.tenant_id = a.tenant_id AND rp.role_id = a.role_id
      JOIN tenant_permissions p ON p.id = rp.permission_id
     WHERE m.tenant_id = p_tenant_id
       AND m.user_id = p_actor_user_id AND m.status = 'active'
       AND p.code = 'tenant.members.invite'
  ) THEN
    RAISE EXCEPTION 'tenant invitation permission required' USING ERRCODE = '42501';
  END IF;

  UPDATE tenant_invitations
     SET status = 'revoked', revoked_at = now()
   WHERE id = p_invitation_id AND tenant_id = p_tenant_id
     AND status = 'pending' AND expires_at > now()
  RETURNING email_normalized INTO v_email;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'pending invitation not found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO platform_audit_events(
    actor_user_id, action, target_type, target_id, reason, metadata
  )
  VALUES (
    p_actor_user_id, 'tenant.invitation.revoked', 'tenant_invitation',
    p_invitation_id, nullif(trim(p_reason), ''),
    jsonb_build_object('tenant_id', p_tenant_id, 'email', v_email)
  );
END;
$m9_invite_revoke$;

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
  v_email text;
  v_existing_status text;
  v_primary_location uuid;
BEGIN
  IF p_token_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid invitation token' USING ERRCODE = '22023';
  END IF;

  SELECT lower(cp.normalized_value)
    INTO v_email
    FROM users u
    JOIN user_contact_points cp ON cp.user_id = u.id
   WHERE u.id = p_user_id AND u.status = 'active'
     AND cp.contact_type = 'email' AND cp.is_verified IS TRUE
   ORDER BY cp.is_primary DESC
   LIMIT 1
   FOR UPDATE OF u;

  IF v_email IS NULL THEN
    RAISE EXCEPTION 'active verified global identity required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_invitation
    FROM tenant_invitations
   WHERE token_hash = p_token_hash
   FOR UPDATE;

  IF NOT FOUND OR v_invitation.status <> 'pending'
     OR v_invitation.expires_at <= now()
     OR v_invitation.email_normalized <> v_email THEN
    RAISE EXCEPTION 'invitation is invalid, expired, or belongs to another email'
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

  DELETE FROM membership_role_assignments
   WHERE tenant_id = v_invitation.tenant_id
     AND membership_id = v_membership_id;

  INSERT INTO membership_role_assignments(
    tenant_id, membership_id, role_id, assigned_by
  )
  VALUES (
    v_invitation.tenant_id, v_membership_id,
    v_invitation.role_id, v_invitation.invited_by
  );

  SELECT id INTO v_primary_location
    FROM locations
   WHERE tenant_id = v_invitation.tenant_id AND is_primary IS TRUE
     AND is_active IS TRUE
   ORDER BY created_at
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

REVOKE ALL ON FUNCTION create_tenant_invitation(uuid, uuid, text, text, uuid, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION list_tenant_invitations(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION revoke_tenant_invitation(uuid, uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION accept_tenant_invitation(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_tenant_invitation(uuid, uuid, text, text, uuid, timestamptz) TO miselium_app;
GRANT EXECUTE ON FUNCTION list_tenant_invitations(uuid, uuid) TO miselium_app;
GRANT EXECUTE ON FUNCTION revoke_tenant_invitation(uuid, uuid, uuid, text) TO miselium_app;
GRANT EXECUTE ON FUNCTION accept_tenant_invitation(uuid, text) TO miselium_app;

COMMIT;
