-- Miselium M9 / 0003 Tenant RBAC and invitation role binding
-- PostgreSQL 16+. Additive: does not rewrite prior migration files.
BEGIN;

-- Canonical tenant permission vocabulary. Platform/module permissions are
-- intentionally absent: tenant administrators cannot provision modules.
INSERT INTO tenant_permissions(code, description) VALUES
  ('tenant.members.read', 'View tenant memberships'),
  ('tenant.members.invite', 'Invite users to the tenant'),
  ('tenant.members.manage', 'Activate, suspend, and remove tenant memberships'),
  ('tenant.roles.read', 'View tenant roles and permissions'),
  ('tenant.roles.manage', 'Create and maintain tenant roles and permission grants'),
  ('tenant.settings.read', 'View tenant settings'),
  ('tenant.settings.manage', 'Update tenant settings'),
  ('tenant.locations.read', 'View tenant locations'),
  ('tenant.locations.manage', 'Create and maintain tenant locations')
ON CONFLICT (code) DO NOTHING;

CREATE OR REPLACE FUNCTION ensure_tenant_default_roles(p_tenant_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO tenant_roles(tenant_id, code, name, is_system)
  VALUES
    (p_tenant_id, 'owner', 'Owner', true),
    (p_tenant_id, 'admin', 'Administrator', true),
    (p_tenant_id, 'member', 'Member', true)
  ON CONFLICT (tenant_id, code) DO NOTHING;

  -- Owner and Tenant Admin can administer their own tenant RBAC and settings.
  -- This does not grant any platform-level or module-provisioning permission.
  INSERT INTO tenant_role_permissions(tenant_id, role_id, permission_id)
  SELECT p_tenant_id, r.id, p.id
    FROM tenant_roles AS r
    CROSS JOIN tenant_permissions AS p
   WHERE r.tenant_id = p_tenant_id
     AND r.code IN ('owner', 'admin')
  ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

  -- A regular member receives read-only access to tenant operational structure.
  INSERT INTO tenant_role_permissions(tenant_id, role_id, permission_id)
  SELECT p_tenant_id, r.id, p.id
    FROM tenant_roles AS r
    JOIN tenant_permissions AS p
      ON p.code IN (
        'tenant.members.read',
        'tenant.roles.read',
        'tenant.settings.read',
        'tenant.locations.read'
      )
   WHERE r.tenant_id = p_tenant_id
     AND r.code = 'member'
  ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
END;
$$;

-- Seed default roles for tenants that already exist. The tenant-creation
-- service must call this function in the same transaction as tenant creation.
DO $$
DECLARE
  tenant_row record;
BEGIN
  FOR tenant_row IN SELECT id FROM tenants LOOP
    PERFORM ensure_tenant_default_roles(tenant_row.id);
  END LOOP;
END;
$$;

-- Existing memberships are assigned the least-privileged built-in role.
-- Any ownership/admin promotion must be an explicit audited service action.
INSERT INTO membership_role_assignments(tenant_id, membership_id, role_id)
SELECT tm.tenant_id, tm.id, r.id
  FROM tenant_memberships AS tm
  JOIN tenant_roles AS r
    ON r.tenant_id = tm.tenant_id
   AND r.code = 'member'
ON CONFLICT (tenant_id, membership_id, role_id) DO NOTHING;

-- Bind invitations to a tenant-scoped role, rather than accepting free-form
-- role strings from the client. Existing invitations are conservatively
-- backfilled to the member role.
ALTER TABLE tenant_invitations
  ADD COLUMN role_id uuid;

UPDATE tenant_invitations AS i
   SET role_id = r.id
  FROM tenant_roles AS r
 WHERE r.tenant_id = i.tenant_id
   AND r.code = 'member'
   AND i.role_id IS NULL;

ALTER TABLE tenant_invitations
  ALTER COLUMN role_id SET NOT NULL;

ALTER TABLE tenant_invitations
  ADD CONSTRAINT fk_tenant_invitation_role
  FOREIGN KEY (tenant_id, role_id)
  REFERENCES tenant_roles(tenant_id, id)
  ON DELETE RESTRICT;

CREATE INDEX ix_tenant_invitations_tenant_role
  ON tenant_invitations(tenant_id, role_id);

COMMIT;
