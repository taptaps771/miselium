-- Least-privilege read grants required by the M9 login and tenant-selection API.
-- Run after creating the LOGIN/NOSUPERUSER/NOBYPASSRLS role miselium_app.
BEGIN;

GRANT USAGE ON SCHEMA public TO miselium_app;

GRANT SELECT (id, status) ON users TO miselium_app;
GRANT SELECT (user_id, contact_type, normalized_value, is_verified)
  ON user_contact_points TO miselium_app;
GRANT SELECT (user_id, provider, password_hash, is_primary, created_at)
  ON user_auth_identities TO miselium_app;

GRANT SELECT (id, status, code, name) ON tenants TO miselium_app;
GRANT SELECT (id, tenant_id, user_id, status) ON tenant_memberships TO miselium_app;

GRANT SELECT (tenant_id, membership_id, role_id)
  ON membership_role_assignments TO miselium_app;
GRANT SELECT (tenant_id, id) ON tenant_roles TO miselium_app;
GRANT SELECT (tenant_id, role_id, permission_id)
  ON tenant_role_permissions TO miselium_app;
GRANT SELECT (id, code) ON tenant_permissions TO miselium_app;

COMMIT;
