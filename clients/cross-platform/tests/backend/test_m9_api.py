from __future__ import annotations

from uuid import uuid4

import httpx
import pytest

from app.backend.m9_api import create_m9_app
from app.backend.m9_identity import (
    IdentityNotFound,
    PasswordIdentity,
    TenantAccessDenied,
    TenantOption,
    TenantPrincipal,
)
from app.backend.security.m9_tokens import decode_m9_access_token
from app.backend.security.passwords import hash_password


class FakeSession:
    def __init__(self) -> None:
        self.committed = False
        self.rolled_back = False

    def __enter__(self) -> FakeSession:
        return self

    def __exit__(self, *_args: object) -> None:
        return None

    def commit(self) -> None:
        self.committed = True

    def rollback(self) -> None:
        self.rolled_back = True


class FakeRepository:
    user_id = uuid4()
    tenant_id = uuid4()
    membership_id = uuid4()
    password_hash = hash_password("correct horse battery")

    def __init__(self, _session: FakeSession) -> None:
        pass

    def resolve_password_identity(self, email: str) -> PasswordIdentity:
        if email != "member@example.com":
            raise IdentityNotFound()
        return PasswordIdentity(
            user_id=self.user_id,
            account_status="active",
            normalized_email=email,
            password_hash=self.password_hash,
        )

    def list_active_tenants(self, user_id):
        assert user_id == self.user_id
        return (
            TenantOption(
                tenant_id=self.tenant_id,
                membership_id=self.membership_id,
                tenant_code="farm-one",
                tenant_name="Farm One",
            ),
        )

    def require_active_tenant_membership(self, *, user_id, tenant_id):
        if user_id != self.user_id or tenant_id != self.tenant_id:
            raise TenantAccessDenied()
        return TenantPrincipal(
            user_id=self.user_id,
            tenant_id=self.tenant_id,
            membership_id=self.membership_id,
            account_status="active",
            membership_status="active",
            tenant_status="active",
            tenant_code="farm-one",
            tenant_name="Farm One",
        )

    def effective_permissions(self, *, tenant_id, membership_id):
        assert tenant_id == self.tenant_id
        assert membership_id == self.membership_id
        return frozenset({"tenant.locations.read", "tenant.members.read"})


@pytest.fixture
def api_client(monkeypatch):
    monkeypatch.setenv("MISELIUM_JWT_SECRET", "test-secret-that-is-long-enough-for-miselium")
    app = create_m9_app(
        session_factory=FakeSession,
        repository_factory=FakeRepository,
    )
    transport = httpx.ASGITransport(app=app)
    return httpx.AsyncClient(
        transport=transport,
        base_url="http://testserver",
    )


@pytest.mark.asyncio
async def test_global_login_then_tenant_selection_then_me(api_client):
    async with api_client as client:
        login = await client.post(
            "/v1/auth/login",
            json={"email": "member@example.com", "password": "correct horse battery"},
        )
        assert login.status_code == 200
        login_data = login.json()
        assert len(login_data["tenants"]) == 1
        assert login_data["tenants"][0]["tenant_id"] == str(FakeRepository.tenant_id)
        assert "access_token" not in login_data

        selection_headers = {"Authorization": f"Bearer {login_data['selection_token']}"}
        tenant_list = await client.get("/v1/auth/tenants", headers=selection_headers)
        assert tenant_list.status_code == 200
        assert tenant_list.json()[0]["code"] == "farm-one"

        selected = await client.post(
            "/v1/auth/select-tenant",
            headers=selection_headers,
            json={"tenant_id": str(FakeRepository.tenant_id)},
        )
        assert selected.status_code == 200
        selected_data = selected.json()
        assert selected_data["tenant_code"] == "farm-one"
        assert selected_data["permissions"] == [
            "tenant.locations.read",
            "tenant.members.read",
        ]
        assert decode_m9_access_token(selected_data["access_token"]) == (
            FakeRepository.user_id,
            FakeRepository.tenant_id,
        )

        me = await client.get(
            "/v1/me",
            headers={"Authorization": f"Bearer {selected_data['access_token']}"},
        )
        assert me.status_code == 200
        assert me.json()["membership_id"] == str(FakeRepository.membership_id)


@pytest.mark.asyncio
async def test_invalid_global_credentials_are_generic_401(api_client):
    async with api_client as client:
        response = await client.post(
            "/v1/auth/login",
            json={"email": "unknown@example.com", "password": "wrong-password"},
        )
    assert response.status_code == 401
    assert response.json()["detail"] == "Email or password is invalid."


@pytest.mark.asyncio
async def test_tenant_selection_rejects_non_member(api_client):
    async with api_client as client:
        login = await client.post(
            "/v1/auth/login",
            json={"email": "member@example.com", "password": "correct horse battery"},
        )
        headers = {"Authorization": f"Bearer {login.json()['selection_token']}"}
        response = await client.post(
            "/v1/auth/select-tenant",
            headers=headers,
            json={"tenant_id": str(uuid4())},
        )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_selection_token_cannot_be_used_as_access_token(api_client):
    async with api_client as client:
        login = await client.post(
            "/v1/auth/login",
            json={"email": "member@example.com", "password": "correct horse battery"},
        )
        response = await client.get(
            "/v1/me",
            headers={"Authorization": f"Bearer {login.json()['selection_token']}"},
        )
    assert response.status_code == 401


def test_m9_api_refuses_legacy_sqlite_database():
    import pytest

    with pytest.raises(RuntimeError, match="requires a PostgreSQL"):
        create_m9_app(database_url="sqlite:///./legacy-m7.db")


@pytest.mark.asyncio
async def test_wrong_password_is_returned_as_generic_401(api_client):
    async with api_client as client:
        response = await client.post(
            "/v1/auth/login",
            json={"email": "member@example.com", "password": "incorrect password"},
        )
    assert response.status_code == 401
    assert response.json()["detail"] == "Email or password is invalid."
