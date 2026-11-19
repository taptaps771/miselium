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
  ADD COLUMN approval_reason text,
  ADD CONSTRAINT ck_tenant_approval_metadata
    CHECK (
      (approved_by IS NULL AND approved_at IS NULL)
      OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)
    ) NOT VALID;

INSERT INTO platform_permissions(code, description)
VALUES (
  'platform.tenants.approve',
  'Approve pending tenant registrations and activate tenant access'
)
ON CONFLICT (code) DO NOTHING;

-- The API runtime is a restricted, non-owner, non-BYPASSRLS role.
-- Global registration and platform lifecycle operations are explicit grants.
GRANT SELECT, INSERT ON users TO miselium_app;
GRANT UPDATE (status) ON users TO miselium_app;
GRANT SELECT, INSERT ON user_profiles TO miselium_app;
GRANT SELECT, INSERT ON user_auth_identities TO miselium_app;
GRANT SELECT, INSERT, UPDATE (is_verified, is_primary, verified_at)
  ON user_contact_points TO miselium_app;
GRANT SELECT, INSERT, UPDATE (consumed_at)
  ON global_email_verification_challenges TO miselium_app;
GRANT SELECT, INSERT, UPDATE (status, approved_by, approved_at, approval_reason)
  ON tenants TO miselium_app;
GRANT SELECT, INSERT ON platform_audit_events TO miselium_app;
GRANT SELECT ON platform_user_roles, platform_roles,
  platform_role_permissions, platform_permissions TO miselium_app;

-- RLS still requires transaction-local tenant context for these tenant-owned
-- inserts; grants do not bypass any row-level policy.
GRANT SELECT ON tenant_permissions TO miselium_app;
GRANT SELECT, INSERT ON tenant_memberships, tenant_roles,
  tenant_role_permissions, membership_role_assignments,
  locations, membership_location_scopes TO miselium_app;

COMMIT;
