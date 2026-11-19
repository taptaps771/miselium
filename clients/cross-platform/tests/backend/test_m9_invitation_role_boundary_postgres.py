from __future__ import annotations

import os
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.exc import DBAPIError


def test_invitation_cannot_grant_role_permissions_not_held_by_inviter():
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL invitation role-boundary environment is not configured")

    actor_id = uuid4()
    tenant_id = uuid4()
    tenant_code = f"invite-boundary-{uuid4().hex[:12]}"
    admin_engine = create_engine(admin_url)
    runtime_engine = create_engine(runtime_url)
    elevated_token_hash = "a" * 64
    safe_token_hash = "b" * 64
    elevated_role_id = uuid4()
    safe_role_id = uuid4()
    actor_role_id = uuid4()
    membership_id = uuid4()

    try:
        with admin_engine.begin() as connection:
            connection.execute(
                text("INSERT INTO users(id, username, status) VALUES (:id, :username, 'active')"),
                {"id": actor_id, "username": f"invite-actor-{actor_id.hex}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenants(id, code, name, status, approved_at, approval_reason)
                    VALUES (:id, :code, 'Invitation Boundary Tenant', 'active', now(), 'CI fixture')
                    """
                ),
                {"id": tenant_id, "code": tenant_code},
            )
            connection.execute(
                text("SELECT ensure_tenant_default_roles(:tenant_id)"),
                {"tenant_id": tenant_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenant_roles(id, tenant_id, code, name, is_system)
                    VALUES
                      (:actor_role_id, :tenant_id, 'invite_limited', 'Invite Limited', false),
                      (:elevated_role_id, :tenant_id, 'elevated_custom', 'Elevated Custom', false),
                      (:safe_role_id, :tenant_id, 'safe_custom', 'Safe Custom', false)
                    """
                ),
                {
                    "actor_role_id": actor_role_id,
                    "elevated_role_id": elevated_role_id,
                    "safe_role_id": safe_role_id,
                    "tenant_id": tenant_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenant_role_permissions(tenant_id, role_id, permission_id)
                    SELECT :tenant_id, :actor_role_id, id
                      FROM tenant_permissions WHERE code='tenant.members.invite'
                    """
                ),
                {"tenant_id": tenant_id, "actor_role_id": actor_role_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenant_role_permissions(tenant_id, role_id, permission_id)
                    SELECT :tenant_id, :elevated_role_id, id
                      FROM tenant_permissions WHERE code='tenant.settings.manage'
                    """
                ),
                {"tenant_id": tenant_id, "elevated_role_id": elevated_role_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenant_memberships(id, tenant_id, user_id, status, joined_at)
                    VALUES (:membership_id, :tenant_id, :actor_id, 'active', now())
                    """
                ),
                {
                    "membership_id": membership_id,
                    "tenant_id": tenant_id,
                    "actor_id": actor_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO membership_role_assignments(tenant_id, membership_id, role_id, assigned_by)
                    VALUES (:tenant_id, :membership_id, :actor_role_id, :actor_id)
                    """
                ),
                {
                    "tenant_id": tenant_id,
                    "membership_id": membership_id,
                    "actor_role_id": actor_role_id,
                    "actor_id": actor_id,
                },
            )

        with runtime_engine.connect() as connection:
            transaction = connection.begin()
            connection.execute(
                text("SELECT set_config('app.user_id', :user_id, true)"),
                {"user_id": str(actor_id)},
            )
            connection.execute(
                text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
                {"tenant_id": str(tenant_id)},
            )
            with pytest.raises(DBAPIError) as raised:
                connection.execute(
                    text(
                        """
                        SELECT * FROM create_tenant_invitation(
                            :actor_id, :tenant_id, :email, :token_hash, :role_id, :expires_at
                        )
                        """
                    ),
                    {
                        "actor_id": str(actor_id),
                        "tenant_id": str(tenant_id),
                        "email": f"elevated-{uuid4().hex}@example.com",
                        "token_hash": elevated_token_hash,
                        "role_id": str(elevated_role_id),
                        "expires_at": datetime.now(UTC) + timedelta(days=7),
                    },
                )
            sqlstate = getattr(raised.value.orig, "sqlstate", getattr(raised.value.orig, "pgcode", None))
            assert sqlstate == "42501"
            transaction.rollback()

        with runtime_engine.connect() as connection:
            transaction = connection.begin()
            connection.execute(
                text("SELECT set_config('app.user_id', :user_id, true)"),
                {"user_id": str(actor_id)},
            )
            connection.execute(
                text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
                {"tenant_id": str(tenant_id)},
            )
            accepted = connection.execute(
                text(
                    """
                    SELECT invitation_id, tenant_id
                      FROM create_tenant_invitation(
                        :actor_id, :tenant_id, :email, :token_hash, :role_id, :expires_at
                      )
                    """
                ),
                {
                    "actor_id": str(actor_id),
                    "tenant_id": str(tenant_id),
                    "email": f"safe-{uuid4().hex}@example.com",
                    "token_hash": safe_token_hash,
                    "role_id": str(safe_role_id),
                    "expires_at": datetime.now(UTC) + timedelta(days=7),
                },
            ).one()
            assert accepted.tenant_id == tenant_id
            transaction.commit()
    finally:
        runtime_engine.dispose()
        admin_engine.dispose()
