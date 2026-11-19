from __future__ import annotations

import os
from uuid import uuid4

import httpx
import pytest
from sqlalchemy import create_engine, text

from app.backend.m9_api import create_m9_app
from app.backend.security.m9_tokens import create_m9_access_token


def _urls() -> tuple[str, str]:
    admin = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime = os.getenv("MISELIUM_DATABASE_URL")
    if not admin or not runtime:
        pytest.skip("PostgreSQL membership administration environment is not configured")
    return admin, runtime


@pytest.mark.asyncio
async def test_tenant_membership_administration_and_last_owner_guard(monkeypatch):
    admin_url, runtime_url = _urls()
    monkeypatch.setenv(
        "MISELIUM_JWT_SECRET",
        "integration-only-secret-value-not-for-production-123456",
    )
    owner_id, second_owner_id, member_id = uuid4(), uuid4(), uuid4()
    tenant_id, isolated_tenant_id = uuid4(), uuid4()
    engine = create_engine(admin_url)
    try:
        with engine.begin() as connection:
            for user_id, username, email in (
                (owner_id, "owner", f"owner-{uuid4().hex}@example.com"),
                (second_owner_id, "second-owner", f"second-{uuid4().hex}@example.com"),
                (member_id, "member", f"member-{uuid4().hex}@example.com"),
            ):
                connection.execute(
                    text("INSERT INTO users(id, username, status) VALUES (:id,:username,'active')"),
                    {"id": user_id, "username": f"{username}-{user_id.hex}"},
                )
                connection.execute(
                    text(
                        """
                        INSERT INTO user_contact_points(
                            user_id,contact_type,value,normalized_value,is_verified,is_primary,verified_at
                        ) VALUES (:id,'email',:email,:email,true,true,now())
                        """
                    ),
                    {"id": user_id, "email": email},
                )

            for current_tenant, code in ((tenant_id, "members"), (isolated_tenant_id, "isolated")):
                connection.execute(
                    text(
                        """
                        INSERT INTO tenants(id,code,name,status,approved_at,approval_reason)
                        VALUES (:id,:code,'Membership Test','active',now(),'CI fixture')
                        """
                    ),
                    {"id": current_tenant, "code": f"{code}-{uuid4().hex[:10]}"},
                )
                connection.execute(
                    text("SELECT ensure_tenant_default_roles(:tenant_id)"),
                    {"tenant_id": current_tenant},
                )

            role_ids = {}
            for code in ("owner", "member"):
                role_ids[code] = connection.execute(
                    text("SELECT id FROM tenant_roles WHERE tenant_id=:tenant_id AND code=:code"),
                    {"tenant_id": tenant_id, "code": code},
                ).scalar_one()

            def add_membership(current_tenant, user_id, role_id):
                membership_id = connection.execute(
                    text(
                        """
                        INSERT INTO tenant_memberships(tenant_id,user_id,status,joined_at)
                        VALUES (:tenant_id,:user_id,'active',now()) RETURNING id
                        """
                    ),
                    {"tenant_id": current_tenant, "user_id": user_id},
                ).scalar_one()
                connection.execute(
                    text(
                        """
                        INSERT INTO membership_role_assignments(tenant_id,membership_id,role_id,assigned_by)
                        VALUES (:tenant_id,:membership_id,:role_id,:actor)
                        """
                    ),
                    {
                        "tenant_id": current_tenant,
                        "membership_id": membership_id,
                        "role_id": role_id,
                        "actor": owner_id,
                    },
                )
                return membership_id

            owner_membership = add_membership(tenant_id, owner_id, role_ids["owner"])
            second_owner_membership = add_membership(tenant_id, second_owner_id, role_ids["owner"])
            member_membership = add_membership(tenant_id, member_id, role_ids["member"])
            isolated_owner_role = connection.execute(
                text("SELECT id FROM tenant_roles WHERE tenant_id=:tenant_id AND code='owner'"),
                {"tenant_id": isolated_tenant_id},
            ).scalar_one()
            isolated_owner_membership = add_membership(isolated_tenant_id, owner_id, isolated_owner_role)

            # The owner in the isolated tenant is the only active owner there.
            assert owner_membership and second_owner_membership and isolated_owner_membership
    finally:
        engine.dispose()

    app = create_m9_app(database_url=runtime_url)
    owner_headers = {
        "Authorization": f"Bearer {create_m9_access_token(user_id=owner_id, tenant_id=tenant_id)}"
    }
    member_headers = {
        "Authorization": f"Bearer {create_m9_access_token(user_id=member_id, tenant_id=tenant_id)}"
    }
    isolated_headers = {
        "Authorization": f"Bearer {create_m9_access_token(user_id=owner_id, tenant_id=isolated_tenant_id)}"
    }
    transport = httpx.ASGITransport(app=app)
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
            listed = await client.get(f"/v1/tenants/{tenant_id}/members", headers=owner_headers)
            assert listed.status_code == 200, listed.text
            assert len(listed.json()) == 3
            assert any(row["membership_id"] == str(member_membership) and row["roles"] == ["member"] for row in listed.json())

            wrong_tenant = await client.get(
                f"/v1/tenants/{isolated_tenant_id}/members", headers=owner_headers
            )
            assert wrong_tenant.status_code == 404

            forbidden = await client.post(
                f"/v1/tenants/{tenant_id}/members/{owner_membership}/suspend",
                headers=member_headers,
                json={"reason": "must not manage"},
            )
            assert forbidden.status_code == 403

            suspended = await client.post(
                f"/v1/tenants/{tenant_id}/members/{member_membership}/suspend",
                headers=owner_headers,
                json={"reason": "temporary access pause"},
            )
            assert suspended.status_code == 204, suspended.text
            reactivated = await client.post(
                f"/v1/tenants/{tenant_id}/members/{member_membership}/reactivate",
                headers=owner_headers,
                json={"reason": "access restored"},
            )
            assert reactivated.status_code == 204, reactivated.text

            role_change = await client.patch(
                f"/v1/tenants/{tenant_id}/members/{member_membership}/role",
                headers=owner_headers,
                json={"role_code": "admin", "reason": "approved responsibility change"},
            )
            assert role_change.status_code == 204, role_change.text
            after_role = await client.get(f"/v1/tenants/{tenant_id}/members", headers=owner_headers)
            member_row = next(row for row in after_role.json() if row["membership_id"] == str(member_membership))
            assert member_row["roles"] == ["admin"]

            owner_demotion = await client.patch(
                f"/v1/tenants/{isolated_tenant_id}/members/{isolated_owner_membership}/role",
                headers=isolated_headers,
                json={"role_code": "member", "reason": "must retain an owner"},
            )
            assert owner_demotion.status_code == 409

            last_owner_suspend = await client.post(
                f"/v1/tenants/{isolated_tenant_id}/members/{isolated_owner_membership}/suspend",
                headers=isolated_headers,
                json={"reason": "must retain an owner"},
            )
            assert last_owner_suspend.status_code == 409

            removed = await client.post(
                f"/v1/tenants/{tenant_id}/members/{member_membership}/remove",
                headers=owner_headers,
                json={"reason": "offboarding"},
            )
            assert removed.status_code == 204, removed.text
            after_remove = await client.get(f"/v1/tenants/{tenant_id}/members", headers=owner_headers)
            removed_row = next(row for row in after_remove.json() if row["membership_id"] == str(member_membership))
            assert removed_row["status"] == "left"
    finally:
        app.state.session_factory.kw["bind"].dispose()

    verify_engine = create_engine(admin_url)
    try:
        with verify_engine.connect() as connection:
            status = connection.execute(
                text("SELECT status FROM users WHERE id=:user_id"), {"user_id": member_id}
            ).scalar_one()
            assert status == "active"  # Removing a tenant membership never deletes the global identity.
    finally:
        verify_engine.dispose()
