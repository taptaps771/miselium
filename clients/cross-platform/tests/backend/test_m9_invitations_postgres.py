from __future__ import annotations

import os
from uuid import uuid4

import httpx
import pytest
from sqlalchemy import create_engine, text

from app.backend.m9_api import create_m9_app
from app.backend.security.m9_tokens import (
    create_m9_access_token,
    create_tenant_selection_token,
)


def _urls() -> tuple[str, str]:
    admin = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime = os.getenv("MISELIUM_DATABASE_URL")
    if not admin or not runtime:
        pytest.skip("PostgreSQL invitation integration environment is not configured")
    return admin, runtime


@pytest.mark.asyncio
async def test_tenant_invitation_create_list_accept_revoke_and_email_binding(monkeypatch):
    admin_url, runtime_url = _urls()
    monkeypatch.setenv(
        "MISELIUM_JWT_SECRET",
        "integration-only-secret-value-not-for-production-123456",
    )
    inviter_id = uuid4()
    invitee_id = uuid4()
    other_id = uuid4()
    tenant_id = uuid4()
    tenant_code = f"invite-{uuid4().hex[:12]}"
    inviter_email = f"owner-{uuid4().hex}@example.com"
    invitee_email = f"member-{uuid4().hex}@example.com"
    other_email = f"other-{uuid4().hex}@example.com"
    sent: list[tuple[str, str, str]] = []

    engine = create_engine(admin_url)
    try:
        with engine.begin() as connection:
            for user_id, email, username in (
                (inviter_id, inviter_email, "inviter"),
                (invitee_id, invitee_email, "invitee"),
                (other_id, other_email, "other"),
            ):
                connection.execute(
                    text("INSERT INTO users(id, username, status) VALUES (:id, :username, 'active')"),
                    {"id": user_id, "username": f"{username}-{user_id.hex}"},
                )
                connection.execute(
                    text(
                        """
                        INSERT INTO user_contact_points(
                            user_id, contact_type, value, normalized_value,
                            is_verified, is_primary, verified_at
                        )
                        VALUES (:id, 'email', :email, :email, true, true, now())
                        """
                    ),
                    {"id": user_id, "email": email},
                )

            connection.execute(
                text(
                    """
                    INSERT INTO tenants(
                        id, code, name, status, approved_at, approval_reason
                    )
                    VALUES (:id, :code, 'Invitation Integration Tenant',
                            'active', now(), 'CI fixture')
                    """
                ),
                {"id": tenant_id, "code": tenant_code},
            )
            connection.execute(
                text("SELECT ensure_tenant_default_roles(:tenant_id)"),
                {"tenant_id": tenant_id},
            )
            owner_role_id = connection.execute(
                text("SELECT id FROM tenant_roles WHERE tenant_id=:tenant_id AND code='owner'"),
                {"tenant_id": tenant_id},
            ).scalar_one()
            membership_id = connection.execute(
                text(
                    """
                    INSERT INTO tenant_memberships(tenant_id, user_id, status, joined_at)
                    VALUES (:tenant_id, :user_id, 'active', now()) RETURNING id
                    """
                ),
                {"tenant_id": tenant_id, "user_id": inviter_id},
            ).scalar_one()
            connection.execute(
                text(
                    """
                    INSERT INTO membership_role_assignments(
                        tenant_id, membership_id, role_id, assigned_by
                    ) VALUES (:tenant_id, :membership_id, :role_id, :user_id)
                    """
                ),
                {
                    "tenant_id": tenant_id,
                    "membership_id": membership_id,
                    "role_id": owner_role_id,
                    "user_id": inviter_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO locations(tenant_id, code, name, is_primary, is_active)
                    VALUES (:tenant_id, 'MAIN', 'Main', true, true)
                    """
                ),
                {"tenant_id": tenant_id},
            )
    finally:
        engine.dispose()

    app = create_m9_app(
        database_url=runtime_url,
        invitation_sender=lambda email, token, tenant_name: sent.append(
            (email, token, tenant_name)
        ),
    )
    inviter_headers = {
        "Authorization": f"Bearer {create_m9_access_token(user_id=inviter_id, tenant_id=tenant_id)}"
    }
    invitee_headers = {
        "Authorization": f"Bearer {create_tenant_selection_token(user_id=invitee_id)}"
    }
    other_headers = {
        "Authorization": f"Bearer {create_tenant_selection_token(user_id=other_id)}"
    }
    transport = httpx.ASGITransport(app=app)

    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
            created = await client.post(
                f"/v1/tenants/{tenant_id}/invitations",
                headers=inviter_headers,
                json={"email": invitee_email, "role_code": "member", "expires_days": 7},
            )
            assert created.status_code == 201, created.text
            assert created.json()["status"] == "pending"
            assert len(sent) == 1
            assert sent[0][0] == invitee_email
            assert sent[0][2] == "Invitation Integration Tenant"

            privileged_role = await client.post(
                f"/v1/tenants/{tenant_id}/invitations",
                headers=inviter_headers,
                json={"email": f"privileged-{uuid4().hex}@example.com", "role_code": "owner"},
            )
            assert privileged_role.status_code == 409

            listed = await client.get(
                f"/v1/tenants/{tenant_id}/invitations",
                headers=inviter_headers,
            )
            assert listed.status_code == 200, listed.text
            assert any(item["invitation_id"] == created.json()["invitation_id"] for item in listed.json())

            wrong_email = await client.post(
                "/v1/invitations/accept",
                headers=other_headers,
                json={"token": sent[0][1]},
            )
            assert wrong_email.status_code == 400

            accepted = await client.post(
                "/v1/invitations/accept",
                headers=invitee_headers,
                json={"token": sent[0][1]},
            )
            assert accepted.status_code == 200, accepted.text
            assert accepted.json()["tenant_id"] == str(tenant_id)

            replay = await client.post(
                "/v1/invitations/accept",
                headers=invitee_headers,
                json={"token": sent[0][1]},
            )
            assert replay.status_code == 400

            duplicate = await client.post(
                f"/v1/tenants/{tenant_id}/invitations",
                headers=inviter_headers,
                json={"email": other_email, "role_code": "member"},
            )
            assert duplicate.status_code == 201, duplicate.text
            second_token = sent[1][1]
            invitation_id = duplicate.json()["invitation_id"]

            revoked = await client.post(
                f"/v1/tenants/{tenant_id}/invitations/{invitation_id}/revoke",
                headers=inviter_headers,
                json={"reason": "No longer needed"},
            )
            assert revoked.status_code == 204, revoked.text

            revoked_accept = await client.post(
                "/v1/invitations/accept",
                headers=other_headers,
                json={"token": second_token},
            )
            assert revoked_accept.status_code == 400

            member_access = await client.post(
                "/v1/auth/select-tenant",
                headers=invitee_headers,
                json={"tenant_id": tenant_id},
            )
            assert member_access.status_code == 200, member_access.text
            assert "tenant.members.read" in member_access.json()["permissions"]
            member_headers = {
                "Authorization": f"Bearer {member_access.json()['access_token']}"
            }
            member_invite_attempt = await client.post(
                f"/v1/tenants/{tenant_id}/invitations",
                headers=member_headers,
                json={"email": f"forbidden-{uuid4().hex}@example.com", "role_code": "member"},
            )
            assert member_invite_attempt.status_code == 403
    finally:
        app.state.session_factory.kw["bind"].dispose()
