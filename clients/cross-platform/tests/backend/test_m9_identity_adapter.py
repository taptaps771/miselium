from __future__ import annotations

from uuid import uuid4

import pytest

from app.backend.m9_identity import (
    AmbiguousIdentity,
    IdentityNotFound,
    InvalidCredentials,
    M9IdentityRepository,
    TenantAccessDenied,
    TenantPermissionDenied,
    verify_password_identity,
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
        if not self.results:
            return Result([])
        return Result(self.results.pop(0))


def test_resolve_password_identity_requires_one_verified_global_email() -> None:
    user_id = uuid4()
    session = FakeSession(
        [{"id": user_id, "status": "active"}],
        [{"password_hash": "scrypt$hash"}],
    )

    identity = M9IdentityRepository(session).resolve_password_identity("  USER@EXAMPLE.COM ")

    assert identity.user_id == user_id
    assert identity.normalized_email == "user@example.com"
    assert identity.password_hash == "scrypt$hash"
    assert "cp.is_verified IS TRUE" in session.calls[0][0]


def test_ambiguous_verified_email_fails_closed() -> None:
    session = FakeSession([
        {"id": uuid4(), "status": "active"},
        {"id": uuid4(), "status": "active"},
    ])

    with pytest.raises(AmbiguousIdentity):
        M9IdentityRepository(session).resolve_password_identity("user@example.com")


def test_missing_verified_email_fails_closed() -> None:
    with pytest.raises(IdentityNotFound):
        M9IdentityRepository(FakeSession([])).resolve_password_identity("user@example.com")


def test_inactive_global_account_cannot_authenticate() -> None:
    session = FakeSession([{"id": uuid4(), "status": "suspended"}])

    with pytest.raises(InvalidCredentials):
        M9IdentityRepository(session).resolve_password_identity("user@example.com")


def test_tenant_principal_requires_active_account_membership_and_tenant() -> None:
    user_id, tenant_id, membership_id = uuid4(), uuid4(), uuid4()
    session = FakeSession([], [], [{
        "user_id": user_id,
        "account_status": "active",
        "membership_id": membership_id,
        "membership_status": "active",
        "tenant_id": tenant_id,
        "tenant_status": "active",
        "tenant_code": "farm-one",
        "tenant_name": "Farm One",
    }])

    principal = M9IdentityRepository(session).require_active_tenant_membership(
        user_id=user_id,
        tenant_id=tenant_id,
    )

    assert principal.membership_id == membership_id
    assert principal.tenant_code == "farm-one"
    assert "tm.status = 'active'" in session.calls[2][0]
    assert "t.status = 'active'" in session.calls[2][0]
    assert "set_config('app.user_id'" in session.calls[0][0]
    assert "set_config('app.tenant_id'" in session.calls[1][0]


def test_missing_active_membership_is_denied() -> None:
    with pytest.raises(TenantAccessDenied):
        M9IdentityRepository(FakeSession([])).require_active_tenant_membership(
            user_id=uuid4(),
            tenant_id=uuid4(),
        )


def test_rls_context_is_transaction_local() -> None:
    session = FakeSession([])
    tenant_id = uuid4()

    M9IdentityRepository(session).set_transaction_tenant(tenant_id)

    sql, params = session.calls[0]
    assert "set_config('app.tenant_id'" in sql
    assert params == {"tenant_id": str(tenant_id)}
    assert sql.rstrip().endswith("true)")


def test_permissions_are_derived_from_tenant_role_assignments() -> None:
    tenant_id, membership_id = uuid4(), uuid4()
    session = FakeSession([], [{"code": "inventory.read"}, {"code": "production.create"}])

    permissions = M9IdentityRepository(session).effective_permissions(
        tenant_id=tenant_id,
        membership_id=membership_id,
    )

    assert permissions == frozenset({"inventory.read", "production.create"})
    sql, params = session.calls[1]
    assert "membership_role_assignments" in sql
    assert "tenant_role_permissions" in sql
    assert params == {
        "tenant_id": str(tenant_id),
        "membership_id": str(membership_id),
    }


def test_missing_tenant_permission_is_denied() -> None:
    repository = M9IdentityRepository(FakeSession([]))

    with pytest.raises(TenantPermissionDenied):
        repository.require_permission(
            tenant_id=uuid4(),
            membership_id=uuid4(),
            permission_code="modules.provision",
        )


def test_password_verification_uses_global_password_identity() -> None:
    user_id = uuid4()
    repository = M9IdentityRepository(FakeSession(
        [{"id": user_id, "status": "active"}],
        [{"password_hash": "encoded"}],
    ))

    identity = verify_password_identity(
        repository,
        email="user@example.com",
        password="secret",
        verifier=lambda password, encoded: password == "secret" and encoded == "encoded",
    )

    assert identity.user_id == user_id



def test_authenticated_user_context_is_transaction_local() -> None:
    session = FakeSession([])
    user_id = uuid4()

    M9IdentityRepository(session).set_transaction_user(user_id)

    sql, params = session.calls[0]
    assert "set_config('app.user_id'" in sql
    assert params == {"user_id": str(user_id)}
    assert sql.rstrip().endswith("true)")


def test_list_active_tenants_sets_user_context_and_returns_memberships() -> None:
    user_id, tenant_a, tenant_b = uuid4(), uuid4(), uuid4()
    membership_a, membership_b = uuid4(), uuid4()
    session = FakeSession(
        [],
        [
            {
                "tenant_id": tenant_a,
                "membership_id": membership_a,
                "code": "farm-a",
                "name": "Farm A",
            },
            {
                "tenant_id": tenant_b,
                "membership_id": membership_b,
                "code": "farm-b",
                "name": "Farm B",
            },
        ],
    )

    tenants = M9IdentityRepository(session).list_active_tenants(user_id)

    assert [tenant.tenant_id for tenant in tenants] == [tenant_a, tenant_b]
    assert [tenant.membership_id for tenant in tenants] == [membership_a, membership_b]
    assert "tm.user_id = :user_id" in session.calls[1][0]
    assert "tm.status = 'active'" in session.calls[1][0]
    assert session.calls[1][1] == {"user_id": str(user_id)}
