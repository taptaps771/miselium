-- Miselium M9 / 0001 Platform Foundation
-- PostgreSQL 16+
-- This migration is additive and does not import or mutate the legacy SQLite dump.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Global identity
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username varchar(80) UNIQUE,
  status varchar(20) NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','pending','suspended','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name varchar(160),
  avatar_uri text,
  locale varchar(20) NOT NULL DEFAULT 'id-ID',
  timezone varchar(64) NOT NULL DEFAULT 'Asia/Jakarta',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_auth_identities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider varchar(40) NOT NULL,
  provider_subject varchar(255) NOT NULL,
  password_hash text,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_subject),
  UNIQUE (user_id, id)
);

CREATE TABLE user_contact_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  contact_type varchar(16) NOT NULL CHECK (contact_type IN ('email','phone')),
  value varchar(320) NOT NULL,
  normalized_value varchar(320) NOT NULL,
  is_verified boolean NOT NULL DEFAULT false,
  is_primary boolean NOT NULL DEFAULT false,
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, contact_type, normalized_value)
);
CREATE UNIQUE INDEX uq_user_primary_contact
  ON user_contact_points(user_id, contact_type) WHERE is_primary;

-- Platform authorization and audit
CREATE TABLE platform_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(60) NOT NULL UNIQUE,
  name varchar(120) NOT NULL
);
CREATE TABLE platform_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(120) NOT NULL UNIQUE,
  description text
);
CREATE TABLE platform_role_permissions (
  role_id uuid NOT NULL REFERENCES platform_roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES platform_permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);
CREATE TABLE platform_user_roles (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES platform_roles(id) ON DELETE RESTRICT,
  granted_at timestamptz NOT NULL DEFAULT now(),
  granted_by uuid REFERENCES users(id) ON DELETE SET NULL,
  PRIMARY KEY (user_id, role_id)
);
CREATE TABLE platform_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action varchar(120) NOT NULL,
  target_type varchar(80),
  target_id uuid,
  reason text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_platform_audit_occurred_at ON platform_audit_events(occurred_at DESC);
CREATE INDEX ix_platform_audit_target ON platform_audit_events(target_type, target_id);

-- Platform catalog and entitlements
CREATE TABLE modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(60) NOT NULL UNIQUE,
  name varchar(120) NOT NULL,
  description text,
  is_available boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(60) NOT NULL UNIQUE,
  name varchar(120) NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE plan_modules (
  plan_id uuid NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  module_id uuid NOT NULL REFERENCES modules(id) ON DELETE RESTRICT,
  limits jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (plan_id, module_id)
);

-- Tenant boundary
CREATE TABLE tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(40) NOT NULL UNIQUE,
  name varchar(180) NOT NULL,
  legal_name varchar(220),
  status varchar(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','active','suspended','closed')),
  default_currency char(3) NOT NULL DEFAULT 'IDR',
  timezone varchar(64) NOT NULL DEFAULT 'Asia/Jakarta',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, code)
);

CREATE TABLE tenant_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  plan_id uuid NOT NULL REFERENCES plans(id) ON DELETE RESTRICT,
  status varchar(20) NOT NULL CHECK (status IN ('trial','active','past_due','suspended','cancelled','expired')),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE TABLE tenant_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  module_id uuid NOT NULL REFERENCES modules(id) ON DELETE RESTRICT,
  status varchar(20) NOT NULL DEFAULT 'enabled' CHECK (status IN ('enabled','disabled','suspended')),
  provisioned_by uuid REFERENCES users(id) ON DELETE SET NULL,
  provisioned_at timestamptz NOT NULL DEFAULT now(),
  disabled_at timestamptz,
  configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (tenant_id, module_id),
  UNIQUE (tenant_id, id)
);

CREATE TABLE tenant_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status varchar(20) NOT NULL DEFAULT 'invited' CHECK (status IN ('invited','active','suspended','left')),
  joined_at timestamptz,
  invited_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, user_id),
  UNIQUE (tenant_id, id)
);
CREATE INDEX ix_memberships_user_status ON tenant_memberships(user_id, status);

CREATE TABLE tenant_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  email_normalized varchar(320) NOT NULL,
  token_hash text NOT NULL UNIQUE,
  status varchar(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','revoked','expired')),
  invited_by uuid REFERENCES users(id) ON DELETE SET NULL,
  expires_at timestamptz NOT NULL,
  accepted_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_tenant_invitations_tenant_status ON tenant_invitations(tenant_id, status);

-- Tenant RBAC
CREATE TABLE tenant_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  code varchar(60) NOT NULL,
  name varchar(120) NOT NULL,
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  UNIQUE (tenant_id, id)
);
CREATE TABLE tenant_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(140) NOT NULL UNIQUE,
  description text
);
CREATE TABLE tenant_role_permissions (
  tenant_id uuid NOT NULL,
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL REFERENCES tenant_permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (tenant_id, role_id, permission_id),
  FOREIGN KEY (tenant_id, role_id) REFERENCES tenant_roles(tenant_id, id) ON DELETE CASCADE
);
CREATE TABLE membership_role_assignments (
  tenant_id uuid NOT NULL,
  membership_id uuid NOT NULL,
  role_id uuid NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by uuid REFERENCES users(id) ON DELETE SET NULL,
  PRIMARY KEY (tenant_id, membership_id, role_id),
  FOREIGN KEY (tenant_id, membership_id) REFERENCES tenant_memberships(tenant_id, id) ON DELETE CASCADE,
  FOREIGN KEY (tenant_id, role_id) REFERENCES tenant_roles(tenant_id, id) ON DELETE CASCADE
);

-- Locations and operational structure
CREATE TABLE locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  code varchar(50) NOT NULL,
  name varchar(150) NOT NULL,
  address text,
  timezone varchar(64),
  is_primary boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  UNIQUE (tenant_id, id)
);
CREATE UNIQUE INDEX uq_locations_one_primary_active
  ON locations(tenant_id) WHERE is_primary AND is_active;

CREATE TABLE membership_location_scopes (
  tenant_id uuid NOT NULL,
  membership_id uuid NOT NULL,
  location_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, membership_id, location_id),
  FOREIGN KEY (tenant_id, membership_id) REFERENCES tenant_memberships(tenant_id, id) ON DELETE CASCADE,
  FOREIGN KEY (tenant_id, location_id) REFERENCES locations(tenant_id, id) ON DELETE CASCADE
);

CREATE TABLE warehouses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  location_id uuid NOT NULL,
  code varchar(50) NOT NULL,
  name varchar(150) NOT NULL,
  warehouse_type varchar(40) NOT NULL DEFAULT 'general',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, location_id) REFERENCES locations(tenant_id, id) ON DELETE RESTRICT
);
CREATE INDEX ix_warehouses_location ON warehouses(tenant_id, location_id);

CREATE TABLE production_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  location_id uuid NOT NULL,
  code varchar(50) NOT NULL,
  name varchar(150) NOT NULL,
  production_type varchar(40) NOT NULL DEFAULT 'general',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, location_id) REFERENCES locations(tenant_id, id) ON DELETE RESTRICT
);

CREATE TABLE kumbungs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  location_id uuid NOT NULL,
  code varchar(50) NOT NULL,
  name varchar(150) NOT NULL,
  capacity numeric(18,3) NOT NULL CHECK (capacity > 0),
  capacity_unit varchar(30) NOT NULL DEFAULT 'baglog',
  environment_type varchar(40) NOT NULL DEFAULT 'standard',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, location_id) REFERENCES locations(tenant_id, id) ON DELETE RESTRICT
);

-- Global parties, tenant-specific business relationships
CREATE TABLE global_parties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  party_type varchar(20) NOT NULL CHECK (party_type IN ('person','organization')),
  display_name varchar(180) NOT NULL,
  legal_name varchar(220),
  tax_identifier varchar(80),
  status varchar(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','blocked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, party_type)
);
CREATE INDEX ix_global_parties_name ON global_parties USING btree (lower(display_name));

CREATE TABLE party_user_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  party_id uuid NOT NULL REFERENCES global_parties(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  verification_status varchar(20) NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending','verified','rejected','revoked')),
  verified_at timestamptz,
  verified_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (party_id, user_id)
);

CREATE TABLE tenant_customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  party_id uuid NOT NULL REFERENCES global_parties(id) ON DELETE RESTRICT,
  customer_code varchar(50) NOT NULL,
  credit_limit numeric(20,4) NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
  payment_terms_days integer NOT NULL DEFAULT 0 CHECK (payment_terms_days >= 0),
  status varchar(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','blocked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, party_id),
  UNIQUE (tenant_id, customer_code),
  UNIQUE (tenant_id, id)
);
CREATE TABLE tenant_suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  party_id uuid NOT NULL REFERENCES global_parties(id) ON DELETE RESTRICT,
  supplier_code varchar(50) NOT NULL,
  payment_terms_days integer NOT NULL DEFAULT 0 CHECK (payment_terms_days >= 0),
  status varchar(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','blocked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, party_id),
  UNIQUE (tenant_id, supplier_code),
  UNIQUE (tenant_id, id)
);

CREATE TABLE customer_portal_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  tenant_customer_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status varchar(20) NOT NULL DEFAULT 'invited' CHECK (status IN ('invited','active','revoked')),
  granted_at timestamptz NOT NULL DEFAULT now(),
  granted_by uuid REFERENCES users(id) ON DELETE SET NULL,
  revoked_at timestamptz,
  UNIQUE (tenant_id, tenant_customer_id, user_id),
  FOREIGN KEY (tenant_id, tenant_customer_id) REFERENCES tenant_customers(tenant_id, id) ON DELETE CASCADE
);
CREATE TABLE supplier_portal_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  tenant_supplier_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status varchar(20) NOT NULL DEFAULT 'invited' CHECK (status IN ('invited','active','revoked')),
  granted_at timestamptz NOT NULL DEFAULT now(),
  granted_by uuid REFERENCES users(id) ON DELETE SET NULL,
  revoked_at timestamptz,
  UNIQUE (tenant_id, tenant_supplier_id, user_id),
  FOREIGN KEY (tenant_id, tenant_supplier_id) REFERENCES tenant_suppliers(tenant_id, id) ON DELETE CASCADE
);

-- Tenant-specific price lists. Posted document lines must copy immutable snapshots.
CREATE TABLE tenant_price_lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  code varchar(50) NOT NULL,
  name varchar(150) NOT NULL,
  currency char(3) NOT NULL DEFAULT 'IDR',
  valid_from timestamptz,
  valid_until timestamptz,
  status varchar(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  UNIQUE (tenant_id, id),
  CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until > valid_from)
);
CREATE TABLE tenant_price_list_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  price_list_id uuid NOT NULL,
  item_code varchar(80) NOT NULL,
  item_name varchar(180) NOT NULL,
  unit_name varchar(40) NOT NULL,
  unit_price numeric(20,4) NOT NULL CHECK (unit_price >= 0),
  currency char(3) NOT NULL,
  effective_from timestamptz NOT NULL,
  effective_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, price_list_id) REFERENCES tenant_price_lists(tenant_id, id) ON DELETE CASCADE,
  CHECK (effective_until IS NULL OR effective_until > effective_from)
);
CREATE INDEX ix_price_items_lookup ON tenant_price_list_items(tenant_id, price_list_id, item_code, effective_from DESC);

-- Tenant audit trail
CREATE TABLE tenant_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action varchar(120) NOT NULL,
  entity_type varchar(100),
  entity_id uuid,
  reason text,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
CREATE INDEX ix_tenant_audit_time ON tenant_audit_events(tenant_id, occurred_at DESC);
CREATE INDEX ix_tenant_audit_entity ON tenant_audit_events(tenant_id, entity_type, entity_id);

-- Updated-at triggers
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['users','user_profiles','tenants','locations','global_parties'] LOOP
    EXECUTE format('CREATE TRIGGER %I_set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t, t);
  END LOOP;
END $$;

-- RLS: tenant-owned tables. Policies are fail-closed without app.tenant_id.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'tenant_subscriptions','tenant_modules','tenant_memberships','tenant_invitations',
    'tenant_roles','tenant_role_permissions','membership_role_assignments',
    'locations','membership_location_scopes','warehouses','production_units','kumbungs',
    'tenant_customers','tenant_suppliers','customer_portal_access','supplier_portal_access',
    'tenant_price_lists','tenant_price_list_items','tenant_audit_events'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY tenant_isolation ON %I USING (tenant_id = current_tenant_id()) WITH CHECK (tenant_id = current_tenant_id())',
      t
    );
  END LOOP;
END $$;

COMMIT;
