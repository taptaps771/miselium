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
        pytest.skip("PostgreSQL tenant role administration environment is not configured")
    return admin, runtime


@pytest.mark.asyncio
async def test_custom_tenant_roles_and_permission_escalation_guard(monkeypatch):
    admin_url, runtime_url = _urls()
    monkeypatch.setenv(
        "MISELIUM_JWT_SECRET",
        "integration-only-secret-value-not-for-production-123456",
    )
    owner_id, manager_id = uuid4(), uuid4()
    tenant_id = uuid4()
    engine = create_engine(admin_url)
    try:
        with engine.begin() as connection:
            for user_id, label in ((owner_id, "owner"), (manager_id, "manager")):
                email = f"{label}-{uuid4().hex}@example.com"
                connection.execute(
                    text("INSERT INTO users(id,status) VALUES (:id,'active')"),
                    {"id": user_id},
                )
                connection.execute(
                    text("""
                        INSERT INTO user_contact_points(
                            user_id,contact_type,value,normalized_value,is_verified,is_primary,verified_at
                        ) VALUES (:id,'email',:email,:email,true,true,now())
                    """),
                    {"id": user_id, "email": email},
                )
            connection.execute(
                text("""
                    INSERT INTO tenants(id,code,name,status,approved_at,approval_reason)
                    VALUES (:id,:code,'Role Administration Test','active',now(),'CI fixture')
                """),
                {"id": tenant_id, "code": f"roles-{uuid4().hex[:12]}"},
            )
            connection.execute(
                text("SELECT ensure_tenant_default_roles(:tenant_id)"),
                {"tenant_id": tenant_id},
            )
            roles = {
                code: connection.execute(
                    text("SELECT id FROM tenant_roles WHERE tenant_id=:tenant_id AND code=:code"),
                    {"tenant_id": tenant_id, "code": code},
                ).scalar_one()
                for code in ("owner", "member")
            }
            memberships = {}
            for user_id, role_id in ((owner_id, roles["owner"]), (manager_id, roles["member"])):
                membership_id = connection.execute(
                    text("""
                        INSERT INTO tenant_memberships(tenant_id,user_id,status,joined_at)
                        VALUES (:tenant_id,:user_id,'active',now()) RETURNING id
                    """),
                    {"tenant_id": tenant_id, "user_id": user_id},
                ).scalar_one()
                memberships[user_id] = membership_id
                connection.execute(
                    text("""
                        INSERT INTO membership_role_assignments(tenant_id,membership_id,role_id,assigned_by)
                        VALUES (:tenant_id,:membership_id,:role_id,:actor)
                    """),
                    {
                        "tenant_id": tenant_id,
                        "membership_id": membership_id,
                        "role_id": role_id,
                        "actor": owner_id,
                    },
                )
    finally:
        engine.dispose()

    app = create_m9_app(database_url=runtime_url)
    owner_headers = {
        "Authorization": f"Bearer {create_m9_access_token(user_id=owner_id, tenant_id=tenant_id)}"
    }
    member_headers = {
        "Authorization": f"Bearer {create_m9_access_token(user_id=manager_id, tenant_id=tenant_id)}"
    }
    transport = httpx.ASGITransport(app=app)
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
            created = await client.post(
                f"/v1/tenants/{tenant_id}/roles",
                headers=owner_headers,
                json={
                    "code": "operations-manager",
                    "name": "Operations Manager",
                    "reason": "CI custom role",
                },
            )
            assert created.status_code == 201, created.text
            role_id = created.json()["role_id"]
            assert created.json()["permissions"] == []

            catalog = await client.get(
                f"/v1/tenants/{tenant_id}/permissions", headers=owner_headers
            )
            assert catalog.status_code == 200, catalog.text
            assert any(item["code"] == "tenant.roles.manage" and item["actor_can_grant"] for item in catalog.json())

            configured = await client.put(
                f"/v1/tenants/{tenant_id}/roles/{role_id}/permissions",
                headers=owner_headers,
                json={
                    "permission_codes": [
                        "tenant.roles.read",
                        "tenant.roles.manage",
                        "tenant.members.read",
                    ],
                    "reason": "Grant limited role administration",
                },
            )
            assert configured.status_code == 204, configured.text

            assigned = await client.patch(
                f"/v1/tenants/{tenant_id}/members/{memberships[manager_id]}/role",
                headers=owner_headers,
                json={"role_code": "operations-manager", "reason": "Assign custom role"},
            )
            assert assigned.status_code == 204, assigned.text

            visible = await client.get(
                f"/v1/tenants/{tenant_id}/roles", headers=member_headers
            )
            assert visible.status_code == 200, visible.text
            custom = next(item for item in visible.json() if item["role_id"] == role_id)
            assert set(custom["permissions"]) == {
                "tenant.roles.read",
                "tenant.roles.manage",
                "tenant.members.read",
            }

            denied_escalation = await client.put(
                f"/v1/tenants/{tenant_id}/roles/{role_id}/permissions",
                headers=member_headers,
                json={
                    "permission_codes": [
                        "tenant.roles.read",
                        "tenant.roles.manage",
                        "tenant.members.read",
                        "tenant.settings.manage",
                    ],
                    "reason": "Must not grant a permission the actor lacks",
                },
            )
            assert denied_escalation.status_code == 403, denied_escalation.text

            forbidden_create = await client.post(
                f"/v1/tenants/{tenant_id}/roles",
                headers={
                    "Authorization": f"Bearer {create_m9_access_token(user_id=uuid4(), tenant_id=tenant_id)}"
                },
                json={"code": "unauthorized-role", "name": "Unauthorized"},
            )
            assert forbidden_create.status_code in {401, 403}

            system_role = await client.get(
                f"/v1/tenants/{tenant_id}/roles", headers=owner_headers
            )
            owner_role_id = next(item["role_id"] for item in system_role.json() if item["code"] == "owner")
            immutable = await client.put(
                f"/v1/tenants/{tenant_id}/roles/{owner_role_id}/permissions",
                headers=owner_headers,
                json={"permission_codes": ["tenant.members.read"]},
            )
            assert immutable.status_code == 409, immutable.text
    finally:
        app.state.session_factory.kw["bind"].dispose()
