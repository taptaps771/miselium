-- Miselium M9 / 0005 Global registration and tenant lifecycle
-- PostgreSQL 16+. Additive only; preserves all existing users and tenant data.
BEGIN;

CREATE TABLE global_email_verification_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  contact_point_id uuid NOT NULL REFERENCES user_contact_points(id) ON DELETE CASCADE,
  token_hash char(64) NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at)
);
CREATE INDEX ix_email_verification_user_pending
  ON global_email_verification_challenges(user_id, expires_at DESC)
  WHERE consumed_at IS NULL;

-- A verified email identifies at most one global account. Existing duplicate
-- verified addresses must be resolved explicitly before this migration applies.
DO $$
BEGIN
  IF EXISTS (
    SELECT normalized_value
      FROM user_contact_points
     WHERE contact_type = 'email' AND is_verified
     GROUP BY normalized_value
    HAVING count(DISTINCT user_id) > 1
  ) THEN
    RAISE EXCEPTION
      'Duplicate verified global email addresses exist; resolve identity collisions before migration 0005';
  END IF;
END $$;

CREATE UNIQUE INDEX uq_global_verified_email
  ON user_contact_points(normalized_value)
  WHERE contact_type = 'email' AND is_verified;

ALTER TABLE tenants
  ADD COLUMN approved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN approved_at timestamptz,
  ADD COLUMN approval_reason text;

-- Preserve existing active tenants without inventing a platform approver.
-- Their creation timestamp is retained as the legacy activation baseline.
UPDATE tenants
   SET approved_at = created_at,
       approval_reason = 'Grandfathered active tenant from pre-approval lifecycle'
 WHERE status = 'active';

ALTER TABLE tenants
  ADD CONSTRAINT ck_tenant_approval_metadata
  CHECK (status <> 'active' OR approved_at IS NOT NULL);

INSERT INTO platform_permissions(code, description)
VALUES (
  'platform.tenants.approve',
  'Approve pending tenant registrations and activate tenant access'
)
ON CONFLICT (code) DO NOTHING;

-- Approval is a narrowly scoped SECURITY DEFINER operation. The API role
-- cannot directly UPDATE tenant status, even if a request handler is bypassed.
CREATE OR REPLACE FUNCTION platform_approve_pending_tenant(
  p_actor_user_id uuid,
  p_tenant_id uuid,
  p_reason text
)
RETURNS TABLE(tenant_id uuid, tenant_code varchar(40), tenant_name varchar(180))
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $m9_approve$
DECLARE
  v_tenant_id uuid;
  v_tenant_code varchar(40);
  v_tenant_name varchar(180);
BEGIN
  IF length(trim(coalesce(p_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'approval reason is required' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM platform_user_roles AS ur
      JOIN users AS u ON u.id = ur.user_id AND u.status = 'active'
      JOIN platform_role_permissions AS rp ON rp.role_id = ur.role_id
      JOIN platform_permissions AS p ON p.id = rp.permission_id
     WHERE ur.user_id = p_actor_user_id
       AND p.code = 'platform.tenants.approve'
  ) THEN
    RAISE EXCEPTION 'platform permission required' USING ERRCODE = '42501';
  END IF;

  UPDATE tenants AS t
     SET status = 'active',
         approved_by = p_actor_user_id,
         approved_at = now(),
         approval_reason = trim(p_reason)
   WHERE t.id = p_tenant_id
     AND t.status = 'pending'
  RETURNING t.id, t.code, t.name
       INTO v_tenant_id, v_tenant_code, v_tenant_name;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'tenant is not pending or does not exist' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO platform_audit_events(
    actor_user_id, action, target_type, target_id, reason, metadata
  )
  VALUES (
    p_actor_user_id, 'tenant.registration_approved', 'tenant', v_tenant_id,
    trim(p_reason),
    jsonb_build_object('tenant_code', v_tenant_code, 'tenant_name', v_tenant_name)
  );

  RETURN QUERY SELECT v_tenant_id, v_tenant_code, v_tenant_name;
END;
$m9_approve$;

REVOKE ALL ON FUNCTION platform_approve_pending_tenant(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION platform_approve_pending_tenant(uuid, uuid, text)
  TO miselium_app;

-- Column-level grants keep global identity data least-privileged even
-- when a SQL injection reaches the runtime connection.
GRANT SELECT (id, status) ON users TO miselium_app;
GRANT INSERT (status) ON users TO miselium_app;
GRANT UPDATE (status) ON users TO miselium_app;

GRANT INSERT (user_id, display_name) ON user_profiles TO miselium_app;
GRANT SELECT (user_id, provider, password_hash, is_primary, created_at)
  ON user_auth_identities TO miselium_app;
GRANT INSERT (user_id, provider, provider_subject, password_hash, is_primary)
  ON user_auth_identities TO miselium_app;

GRANT SELECT (id, user_id, contact_type, normalized_value, is_verified)
  ON user_contact_points TO miselium_app;
GRANT INSERT (user_id, contact_type, value, normalized_value, is_verified, is_primary)
  ON user_contact_points TO miselium_app;
GRANT UPDATE (is_verified, is_primary, verified_at)
  ON user_contact_points TO miselium_app;

GRANT SELECT (id, user_id, contact_point_id, token_hash, expires_at, consumed_at)
  ON global_email_verification_challenges TO miselium_app;
GRANT INSERT (user_id, contact_point_id, token_hash, expires_at)
  ON global_email_verification_challenges TO miselium_app;
GRANT UPDATE (consumed_at)
  ON global_email_verification_challenges TO miselium_app;

GRANT SELECT (id, code, name, status, created_at) ON tenants TO miselium_app;
GRANT INSERT (code, name, legal_name, status) ON tenants TO miselium_app;

GRANT INSERT (actor_user_id, action, target_type, target_id, reason, metadata)
  ON platform_audit_events TO miselium_app;
GRANT SELECT (user_id, role_id) ON platform_user_roles TO miselium_app;
GRANT SELECT (id) ON platform_roles TO miselium_app;
GRANT SELECT (role_id, permission_id) ON platform_role_permissions TO miselium_app;
GRANT SELECT (id, code) ON platform_permissions TO miselium_app;

-- RLS still requires transaction-local tenant context for tenant-owned writes.
GRANT SELECT (id, code) ON tenant_permissions TO miselium_app;
GRANT SELECT (id, tenant_id, user_id, status, joined_at)
  ON tenant_memberships TO miselium_app;
GRANT INSERT (tenant_id, user_id, status, joined_at)
  ON tenant_memberships TO miselium_app;

GRANT SELECT (id, tenant_id, code) ON tenant_roles TO miselium_app;
GRANT INSERT (tenant_id, code, name, is_system) ON tenant_roles TO miselium_app;
GRANT SELECT (tenant_id, role_id, permission_id)
  ON tenant_role_permissions TO miselium_app;
GRANT INSERT (tenant_id, role_id, permission_id)
  ON tenant_role_permissions TO miselium_app;
GRANT SELECT (tenant_id, membership_id, role_id)
  ON membership_role_assignments TO miselium_app;
GRANT INSERT (tenant_id, membership_id, role_id, assigned_by)
  ON membership_role_assignments TO miselium_app;

GRANT SELECT (id) ON locations TO miselium_app;
GRANT INSERT (tenant_id, code, name, address, is_primary, is_active)
  ON locations TO miselium_app;
GRANT INSERT (tenant_id, membership_id, location_id)
  ON membership_location_scopes TO miselium_app;
COMMIT;
