from __future__ import annotations

import os
from uuid import UUID, uuid4

import httpx
import pytest
from sqlalchemy import create_engine, text

from app.backend.m9_api import create_m9_app
from app.backend.security.m9_tokens import decode_tenant_selection_token


def _database_urls() -> tuple[str, str]:
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL M9 integration environment is not configured")
    return admin_url, runtime_url


def _grant_platform_tenant_approval(admin_url: str, email: str) -> UUID:
    engine = create_engine(admin_url)
    try:
        with engine.begin() as connection:
            user_id = connection.execute(
                text(
                    """
                    SELECT cp.user_id
                      FROM user_contact_points cp
                     WHERE cp.contact_type = 'email'
                       AND cp.normalized_value = :email
                       AND cp.is_verified IS TRUE
                    """
                ),
                {"email": email},
            ).scalar_one()
            role_id = connection.execute(
                text(
                    """
                    INSERT INTO platform_roles(code, name)
                    VALUES ('ci-tenant-approver', 'CI Tenant Approver')
                    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
                    RETURNING id
                    """
                )
            ).scalar_one()
            connection.execute(
                text(
                    """
                    INSERT INTO platform_role_permissions(role_id, permission_id)
                    SELECT :role_id, id FROM platform_permissions
                     WHERE code = 'platform.tenants.approve'
                    ON CONFLICT DO NOTHING
                    """
                ),
                {"role_id": role_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO platform_user_roles(user_id, role_id)
                    VALUES (:user_id, :role_id)
                    ON CONFLICT DO NOTHING
                    """
                ),
                {"user_id": user_id, "role_id": role_id},
            )
        return UUID(str(user_id))
    finally:
        engine.dispose()


@pytest.mark.asyncio
async def test_global_registration_tenant_request_and_platform_approval(monkeypatch):
    admin_url, runtime_url = _database_urls()
    monkeypatch.setenv(
        "MISELIUM_JWT_SECRET",
        "integration-only-secret-value-not-for-production-123456",
    )
    sent_verification: list[tuple[str, str]] = []
    app = create_m9_app(
        database_url=runtime_url,
        verification_sender=lambda email, token: sent_verification.append((email, token)),
    )
    transport = httpx.ASGITransport(app=app)
    email = f"m9-lifecycle-{uuid4().hex}@example.com"
    tenant_code = f"ci-{uuid4().hex[:12]}"

    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
            registered = await client.post(
                "/v1/auth/register",
                json={
                    "email": email,
                    "password": "m9-lifecycle-password-2026",
                    "display_name": "Lifecycle Integration",
                },
            )
            assert registered.status_code == 202, registered.text
            assert len(sent_verification) == 1
            assert sent_verification[0][0] == email

            verified = await client.post(
                "/v1/auth/verify-email",
                json={"token": sent_verification[0][1]},
            )
            assert verified.status_code == 200, verified.text
            replayed = await client.post(
                "/v1/auth/verify-email",
                json={"token": sent_verification[0][1]},
            )
            assert replayed.status_code == 400
            selection_token = verified.json()["selection_token"]
            selection_headers = {"Authorization": f"Bearer {selection_token}"}
            user_id = decode_tenant_selection_token(selection_token)

            tenant = await client.post(
                "/v1/tenants",
                headers=selection_headers,
                json={
                    "code": tenant_code,
                    "name": "Lifecycle Test Tenant",
                    "primary_location_code": "MAIN",
                    "primary_location_name": "Lokasi Utama",
                },
            )
            assert tenant.status_code == 201, tenant.text
            tenant_data = tenant.json()
            assert tenant_data["status"] == "pending"

            not_yet_active = await client.get(
                "/v1/auth/tenants",
                headers=selection_headers,
            )
            assert not_yet_active.status_code == 200
            assert all(item["tenant_id"] != tenant_data["tenant_id"] for item in not_yet_active.json())

            _grant_platform_tenant_approval(admin_url, email)

            pending = await client.get(
                "/v1/platform/tenants/pending",
                headers=selection_headers,
            )
            assert pending.status_code == 200, pending.text
            assert any(item["tenant_id"] == tenant_data["tenant_id"] for item in pending.json())

            approved = await client.post(
                f"/v1/platform/tenants/{tenant_data['tenant_id']}/approve",
                headers=selection_headers,
                json={"reason": "Verified CI lifecycle approval"},
            )
            assert approved.status_code == 204, approved.text

            visible = await client.get(
                "/v1/auth/tenants",
                headers=selection_headers,
            )
            assert visible.status_code == 200, visible.text
            assert any(item["tenant_id"] == tenant_data["tenant_id"] for item in visible.json())

            selected = await client.post(
                "/v1/auth/select-tenant",
                headers=selection_headers,
                json={"tenant_id": tenant_data["tenant_id"]},
            )
            assert selected.status_code == 200, selected.text
            access_headers = {"Authorization": f"Bearer {selected.json()['access_token']}"}
            me = await client.get("/v1/me", headers=access_headers)
            assert me.status_code == 200, me.text
            assert me.json()["user_id"] == str(user_id)
            assert me.json()["tenant_id"] == tenant_data["tenant_id"]
            assert "tenant.settings.manage" in me.json()["permissions"]
    finally:
        app.state.session_factory.kw["bind"].dispose()
