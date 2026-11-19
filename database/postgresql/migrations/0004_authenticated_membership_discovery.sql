-- Miselium M9 / 0004 Authenticated user's own tenant memberships
-- PostgreSQL 16+. Allows the authenticated global user to enumerate only
-- their own active memberships before a tenant context has been selected.
BEGIN;

CREATE OR REPLACE FUNCTION current_app_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

-- Replace the tenant-only SELECT rule for memberships with a narrowly scoped
-- self-read rule. Writes remain restricted to the selected tenant context.
DROP POLICY tenant_isolation ON tenant_memberships;

CREATE POLICY tenant_membership_select_self
  ON tenant_memberships
  FOR SELECT
  USING (
    tenant_id = current_tenant_id()
    OR user_id = current_app_user_id()
  );

CREATE POLICY tenant_membership_write_selected_tenant
  ON tenant_memberships
  FOR ALL
  USING (tenant_id = current_tenant_id())
  WITH CHECK (tenant_id = current_tenant_id());

COMMIT;
