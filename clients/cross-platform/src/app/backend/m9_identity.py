"""Read-only M9 identity and tenant authorization adapter.

This module deliberately does not replace the M7 prototype models or wire
it into the legacy API factory yet. It provides the canonical query boundary
for the next integration step and must be used with the M9 PostgreSQL schema.
"""

from __future__ import annotations

from dataclasses import dataclass
from collections.abc import Callable
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.orm import Session


class IdentityResolutionError(Exception):
    """Base exception for fail-closed global identity resolution."""


class IdentityNotFound(IdentityResolutionError):
    """No verified global email identity exists."""


class AmbiguousIdentity(IdentityResolutionError):
    """More than one global account claims the same verified email."""


class InvalidCredentials(IdentityResolutionError):
    """The account has no usable password credential."""


class TenantAccessDenied(PermissionError):
    """The account has no active membership in the requested tenant."""


class TenantPermissionDenied(PermissionError):
    """The active membership lacks the required tenant permission."""


@dataclass(frozen=True, slots=True)
class PasswordIdentity:
    user_id: UUID
    account_status: str
    normalized_email: str
    password_hash: str


@dataclass(frozen=True, slots=True)
class TenantPrincipal:
    user_id: UUID
    tenant_id: UUID
    membership_id: UUID
    account_status: str
    membership_status: str
    tenant_status: str
    tenant_code: str
    tenant_name: str


class M9IdentityRepository:
    """Queries global identity, active tenant membership, and effective grants."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def resolve_password_identity(self, email: str) -> PasswordIdentity:
        normalized = email.strip().casefold()
        if not normalized:
            raise IdentityNotFound("A verified email address is required.")

        contacts = self._session.execute(
            text(
                """
                SELECT DISTINCT u.id, u.status
                  FROM user_contact_points AS cp
                  JOIN users AS u ON u.id = cp.user_id
                 WHERE cp.contact_type = 'email'
                   AND cp.normalized_value = :email
                   AND cp.is_verified IS TRUE
                """
            ),
            {"email": normalized},
        ).mappings().all()

        if not contacts:
            raise IdentityNotFound("No verified account matches this email.")
        if len(contacts) != 1:
            raise AmbiguousIdentity(
                "This verified email is linked to multiple accounts; "
                "explicit account resolution is required."
            )

        user = contacts[0]
        if user["status"] != "active":
            raise InvalidCredentials("The global account is not active.")

        credential = self._session.execute(
            text(
                """
                SELECT password_hash
                  FROM user_auth_identities
                 WHERE user_id = :user_id
                   AND provider = 'password'
                   AND password_hash IS NOT NULL
                 ORDER BY is_primary DESC, created_at DESC
                 LIMIT 1
                """
            ),
            {"user_id": user["id"]},
        ).mappings().one_or_none()

        if credential is None or not credential["password_hash"]:
            raise InvalidCredentials("No password credential is configured.")

        return PasswordIdentity(
            user_id=UUID(str(user["id"])),
            account_status=str(user["status"]),
            normalized_email=normalized,
            password_hash=str(credential["password_hash"]),
        )

    def require_active_tenant_membership(
        self,
        *,
        user_id: UUID,
        tenant_id: UUID,
    ) -> TenantPrincipal:
        row = self._session.execute(
            text(
                """
                SELECT u.id AS user_id,
                       u.status AS account_status,
                       tm.id AS membership_id,
                       tm.status AS membership_status,
                       t.id AS tenant_id,
                       t.status AS tenant_status,
                       t.code AS tenant_code,
                       t.name AS tenant_name
                  FROM users AS u
                  JOIN tenant_memberships AS tm ON tm.user_id = u.id
                  JOIN tenants AS t ON t.id = tm.tenant_id
                 WHERE u.id = :user_id
                   AND t.id = :tenant_id
                   AND u.status = 'active'
                   AND tm.status = 'active'
                   AND t.status = 'active'
                """
            ),
            {"user_id": str(user_id), "tenant_id": str(tenant_id)},
        ).mappings().one_or_none()

        if row is None:
            raise TenantAccessDenied(
                "An active account, tenant, and tenant membership are required."
            )

        return TenantPrincipal(
            user_id=UUID(str(row["user_id"])),
            tenant_id=UUID(str(row["tenant_id"])),
            membership_id=UUID(str(row["membership_id"])),
            account_status=str(row["account_status"]),
            membership_status=str(row["membership_status"]),
            tenant_status=str(row["tenant_status"]),
            tenant_code=str(row["tenant_code"]),
            tenant_name=str(row["tenant_name"]),
        )

    def set_transaction_tenant(self, tenant_id: UUID) -> None:
        """Set RLS context for this transaction only; never use session SET."""
        self._session.execute(
            text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
            {"tenant_id": str(tenant_id)},
        )

    def effective_permissions(
        self,
        *,
        tenant_id: UUID,
        membership_id: UUID,
    ) -> frozenset[str]:
        rows = self._session.execute(
            text(
                """
                SELECT DISTINCT p.code
                  FROM membership_role_assignments AS mra
                  JOIN tenant_roles AS r
                    ON r.tenant_id = mra.tenant_id
                   AND r.id = mra.role_id
                  JOIN tenant_role_permissions AS rp
                    ON rp.tenant_id = r.tenant_id
                   AND rp.role_id = r.id
                  JOIN tenant_permissions AS p
                    ON p.id = rp.permission_id
                 WHERE mra.tenant_id = :tenant_id
                   AND mra.membership_id = :membership_id
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "membership_id": str(membership_id),
            },
        ).mappings().all()
        return frozenset(str(row["code"]) for row in rows)

    def require_permission(
        self,
        *,
        tenant_id: UUID,
        membership_id: UUID,
        permission_code: str,
    ) -> None:
        if permission_code not in self.effective_permissions(
            tenant_id=tenant_id,
            membership_id=membership_id,
        ):
            raise TenantPermissionDenied(
                f"Missing tenant permission: {permission_code}"
            )


def verify_password_identity(
    repository: M9IdentityRepository,
    *,
    email: str,
    password: str,
    verifier: Callable[[str, str], bool],
) -> PasswordIdentity:
    """Resolve a verified global identity, then delegate hash verification."""
    identity = repository.resolve_password_identity(email)
    if not verifier(password, identity.password_hash):
        raise InvalidCredentials("Email or password is invalid.")
    return identity
