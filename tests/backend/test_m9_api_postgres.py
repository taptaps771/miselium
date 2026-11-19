from __future__ import annotations

import os
from uuid import UUID

import httpx
import pytest
from sqlalchemy import create_engine, text

from app.backend.m9_api import create_m9_app
from app.backend.security.passwords import hash_password


USER_ID = UUID("00000000-0000-0000-0000-000000000901")
TENANT_ID = UUID("00000000-0000-0000-0000-000000000902")
EMAIL = "m9-api-integration@example.com"
PASSWORD = "m9-integration-password"


def _database_urls() -> tuple[str, str]:
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL M9 integration environment is not configured")
    return admin_url, runtime_url


def _seed_identity(admin_url: str) -> None:
    engine = create_engine(admin_url)
    password_hash = hash_password(PASSWORD)
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                INSERT INTO users(id, username, status)
                VALUES (:user_id, 'm9-api-integration-user', 'active')
                ON CONFLICT (id) DO UPDATE SET status = 'active'
                """
            ),
            {"user_id": str(USER_ID)},
        )
        connection.execute(
            text(
                """
                INSERT INTO user_contact_points(
                    user_id, contact_type, value, normalized_value,
                    is_verified, is_primary, verified_at
                )
                VALUES (
                    :user_id, 'email', :email, :email,
                    true, true, now()
                )
                ON CONFLICT (user_id, contact_type, normalized_value)
                DO UPDATE SET is_verified = true, is_primary = true
                """
            ),
            {"user_id": str(USER_ID), "email": EMAIL},
        )
        connection.execute(
            text(
                """
                INSERT INTO user_auth_identities(
                    user_id, provider, provider_subject, password_hash, is_primary
                )
                VALUES (:user_id, 'password', :subject, :password_hash, true)
                ON CONFLICT (provider, provider_subject)
                DO UPDATE SET password_hash = EXCLUDED.password_hash,
                              user_id = EXCLUDED.user_id,
                              is_primary = true
                """
            ),
            {
                "user_id": str(USER_ID),
                "subject": str(USER_ID),
                "password_hash": password_hash,
            },
        )
        connection.execute(
            text(
                """
                INSERT INTO tenants(id, code, name, status, approved_at, approval_reason)
                VALUES (:tenant_id, 'M9-API-TEST', 'M9 API Integration', 'active', now(), 'CI fixture')
                ON CONFLICT (id) DO UPDATE SET status = 'active', approved_at = now()
                """
            ),
            {"tenant_id": str(TENANT_ID)},
        )
        connection.execute(
            text("SELECT ensure_tenant_default_roles(:tenant_id)"),
            {"tenant_id": str(TENANT_ID)},
        )
        membership_id = connection.execute(
            text(
                """
                INSERT INTO tenant_memberships(
                    tenant_id, user_id, status, joined_at
                )
                VALUES (:tenant_id, :user_id, 'active', now())
                ON CONFLICT (tenant_id, user_id)
                DO UPDATE SET status = 'active', joined_at = now()
                RETURNING id
                """
            ),
            {"tenant_id": str(TENANT_ID), "user_id": str(USER_ID)},
        ).scalar_one()
        role_id = connection.execute(
            text(
                """
                SELECT id FROM tenant_roles
                 WHERE tenant_id = :tenant_id AND code = 'admin'
                """
            ),
            {"tenant_id": str(TENANT_ID)},
        ).scalar_one()
        connection.execute(
            text(
                """
                INSERT INTO membership_role_assignments(
                    tenant_id, membership_id, role_id
                )
                VALUES (:tenant_id, :membership_id, :role_id)
                ON CONFLICT DO NOTHING
                """
            ),
            {
                "tenant_id": str(TENANT_ID),
                "membership_id": str(membership_id),
                "role_id": str(role_id),
            },
        )
    engine.dispose()


@pytest.mark.asyncio
async def test_m9_login_and_tenant_selection_use_restricted_postgres_role(monkeypatch):
    admin_url, runtime_url = _database_urls()
    _seed_identity(admin_url)
    monkeypatch.setenv(
        "MISELIUM_JWT_SECRET",
        "integration-only-secret-value-not-for-production-123456",
    )
    app = create_m9_app(database_url=runtime_url)
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(
        transport=transport,
        base_url="http://testserver",
    ) as client:
        login = await client.post(
            "/v1/auth/login",
            json={"email": EMAIL, "password": PASSWORD},
        )
        assert login.status_code == 200, login.text
        login_data = login.json()
        assert len(login_data["tenants"]) == 1
        assert login_data["tenants"][0]["tenant_id"] == str(TENANT_ID)

        selection_headers = {
            "Authorization": f"Bearer {login_data['selection_token']}"
        }
        selected = await client.post(
            "/v1/auth/select-tenant",
            headers=selection_headers,
            json={"tenant_id": str(TENANT_ID)},
        )
        assert selected.status_code == 200, selected.text
        access_token = selected.json()["access_token"]

        me = await client.get(
            "/v1/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert me.status_code == 200, me.text
        assert me.json()["user_id"] == str(USER_ID)
        assert me.json()["tenant_id"] == str(TENANT_ID)
        assert "tenant.members.read" in me.json()["permissions"]

    app.state.session_factory.kw["bind"].dispose()
