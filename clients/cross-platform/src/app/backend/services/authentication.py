"""Canonical M9 global authentication and tenant-selection services.

These functions operate on a caller-managed SQLAlchemy transaction. The API
must commit or roll back the transaction before returning the connection to
the pool. They do not create or mutate legacy M7 ORM tables.
"""
from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from uuid import UUID

from app.backend.m9_identity import (
    M9IdentityRepository,
    PasswordIdentity,
    TenantOption,
    TenantPrincipal,
    verify_password_identity,
)
from app.backend.security.passwords import verify_password


@dataclass(frozen=True, slots=True)
class GlobalLoginResult:
    identity: PasswordIdentity
    active_tenants: tuple[TenantOption, ...]


@dataclass(frozen=True, slots=True)
class TenantAuthorization:
    principal: TenantPrincipal
    permissions: frozenset[str]


def authenticate_global_user(
    repository: M9IdentityRepository,
    *,
    email: str,
    password: str,
    verifier: Callable[[str, str], bool] = verify_password,
) -> GlobalLoginResult:
    """Verify one global password identity and list only its active tenants."""
    identity = verify_password_identity(
        repository,
        email=email,
        password=password,
        verifier=verifier,
    )
    tenants = repository.list_active_tenants(identity.user_id)
    return GlobalLoginResult(identity=identity, active_tenants=tenants)


def authorize_tenant_context(
    repository: M9IdentityRepository,
    *,
    user_id: UUID,
    tenant_id: UUID,
) -> TenantAuthorization:
    """Re-check active membership and resolve tenant RBAC for each selection."""
    principal = repository.require_active_tenant_membership(
        user_id=user_id,
        tenant_id=tenant_id,
    )
    permissions = repository.effective_permissions(
        tenant_id=tenant_id,
        membership_id=principal.membership_id,
    )
    return TenantAuthorization(principal=principal, permissions=permissions)
