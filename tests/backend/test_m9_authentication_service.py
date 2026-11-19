from __future__ import annotations

from uuid import uuid4

from app.backend.m9_identity import M9IdentityRepository
from app.backend.services.authentication import (
    authenticate_global_user,
    authorize_tenant_context,
)


class Result:
    def __init__(self, rows):
        self.rows = rows

    def mappings(self):
        return self

    def all(self):
        return self.rows

    def one_or_none(self):
        if len(self.rows) > 1:
            raise AssertionError("query unexpectedly returned multiple rows")
        return self.rows[0] if self.rows else None


class FakeSession:
    def __init__(self, *results):
        self.results = list(results)
        self.calls = []

    def execute(self, statement, params=None):
        self.calls.append((str(statement), params or {}))
        return Result(self.results.pop(0) if self.results else [])


def test_global_authentication_returns_only_active_tenant_options() -> None:
    user_id, tenant_id, membership_id = uuid4(), uuid4(), uuid4()
    session = FakeSession(
        [{"id": user_id, "status": "active"}],
        [{"password_hash": "encoded"}],
        [],
        [{
            "tenant_id": tenant_id,
            "membership_id": membership_id,
            "code": "farm-a",
            "name": "Farm A",
        }],
    )

    result = authenticate_global_user(
        M9IdentityRepository(session),
        email="user@example.com",
        password="secret",
        verifier=lambda password, encoded: password == "secret" and encoded == "encoded",
    )

    assert result.identity.user_id == user_id
    assert len(result.active_tenants) == 1
    assert result.active_tenants[0].tenant_id == tenant_id
    assert "set_config('app.user_id'" in session.calls[2][0]
    assert "tm.status = 'active'" in session.calls[3][0]


def test_tenant_selection_rechecks_membership_and_loads_permissions() -> None:
    user_id, tenant_id, membership_id = uuid4(), uuid4(), uuid4()
    session = FakeSession(
        [],
        [],
        [{
            "user_id": user_id,
            "account_status": "active",
            "membership_id": membership_id,
            "membership_status": "active",
            "tenant_id": tenant_id,
            "tenant_status": "active",
            "tenant_code": "farm-a",
            "tenant_name": "Farm A",
        }],
        [],
        [{"code": "tenant.members.read"}],
    )

    result = authorize_tenant_context(
        M9IdentityRepository(session),
        user_id=user_id,
        tenant_id=tenant_id,
    )

    assert result.principal.membership_id == membership_id
    assert result.permissions == frozenset({"tenant.members.read"})
    assert "set_config('app.user_id'" in session.calls[0][0]
    assert "set_config('app.tenant_id'" in session.calls[1][0]
    assert "membership_role_assignments" in session.calls[4][0]
