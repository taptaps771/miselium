"""Tenant-scoped invitation and membership lifecycle services."""
from __future__ import annotations

import hashlib
import re
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session


class InvitationError(Exception):
    """Invitation input or state transition is invalid."""


class InvitationPermissionDenied(PermissionError):
    """The current tenant membership cannot manage invitations."""


@dataclass(frozen=True, slots=True)
class CreatedInvitation:
    invitation_id: UUID
    tenant_id: UUID
    email: str
    role_code: str
    raw_token: str
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class TenantInvitation:
    invitation_id: UUID
    email: str
    status: str
    role_code: str
    expires_at: datetime
    created_at: datetime


@dataclass(frozen=True, slots=True)
class AcceptedInvitation:
    tenant_id: UUID
    membership_id: UUID


def _normalize_email(email: str) -> str:
    return email.strip().casefold()


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_invitation(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    email: str,
    role_code: str = "member",
    expires_days: int = 7,
) -> CreatedInvitation:
    normalized = _normalize_email(email)
    role = role_code.strip().lower()
    if not normalized or len(normalized) > 320 or not re.fullmatch(r"[a-z0-9][a-z0-9_-]{1,59}", role):
        raise InvitationError("A valid email and tenant role code are required.")
    if not 1 <= expires_days <= 30:
        raise InvitationError("Invitation expiry must be between 1 and 30 days.")

    role_row = session.execute(
        text(
            """
            SELECT id, code
              FROM tenant_roles
             WHERE tenant_id = :tenant_id AND code = :role_code
            """
        ),
        {"tenant_id": str(tenant_id), "role_code": role},
    ).mappings().one_or_none()
    if role_row is None:
        raise InvitationError("The requested role is not available in this tenant.")

    raw_token = secrets.token_urlsafe(32)
    expires_at = datetime.now(UTC) + timedelta(days=expires_days)
    try:
        row = session.execute(
            text(
                """
                SELECT invitation_id, tenant_id, email_normalized, expires_at
                  FROM create_tenant_invitation(
                    :actor_user_id, :tenant_id, :email, :token_hash,
                    :role_id, :expires_at
                  )
                """
            ),
            {
                "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id),
                "email": normalized,
                "token_hash": _token_hash(raw_token),
                "role_id": str(role_row["id"]),
                "expires_at": expires_at,
            },
        ).mappings().one()
    except DBAPIError as exc:
        sqlstate = getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))
        if sqlstate == "42501":
            raise InvitationPermissionDenied(
                "Tenant invitation permission is required."
            ) from None
        if sqlstate == "23505":
            raise InvitationError(
                "A pending invitation already exists for this email."
            ) from None
        if sqlstate == "23503":
            raise InvitationError("This tenant role cannot be assigned by invitation.") from None
        if sqlstate == "22023":
            raise InvitationError("Invitation details are invalid.") from None
        raise

    return CreatedInvitation(
        invitation_id=UUID(str(row["invitation_id"])),
        tenant_id=UUID(str(row["tenant_id"])),
        email=str(row["email_normalized"]),
        role_code=str(role_row["code"]),
        raw_token=raw_token,
        expires_at=row["expires_at"],
    )


def list_invitations(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
) -> tuple[TenantInvitation, ...]:
    try:
        rows = session.execute(
            text(
                """
                SELECT invitation_id, email_normalized, status,
                       role_code, expires_at, created_at
                  FROM list_tenant_invitations(:actor_user_id, :tenant_id)
                """
            ),
            {"actor_user_id": str(actor_user_id), "tenant_id": str(tenant_id)},
        ).mappings().all()
    except DBAPIError as exc:
        sqlstate = getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))
        if sqlstate == "42501":
            raise InvitationPermissionDenied(
                "Tenant membership read permission is required."
            ) from None
        raise
    return tuple(
        TenantInvitation(
            invitation_id=UUID(str(row["invitation_id"])),
            email=str(row["email_normalized"]),
            status=str(row["status"]),
            role_code=str(row["role_code"]),
            expires_at=row["expires_at"],
            created_at=row["created_at"],
        )
        for row in rows
    )


def revoke_invitation(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    invitation_id: UUID,
    reason: str | None = None,
) -> None:
    try:
        session.execute(
            text(
                """
                SELECT revoke_tenant_invitation(
                    :actor_user_id, :tenant_id, :invitation_id, :reason
                )
                """
            ),
            {
                "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id),
                "invitation_id": str(invitation_id),
                "reason": reason,
            },
        )
    except DBAPIError as exc:
        sqlstate = getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))
        if sqlstate == "42501":
            raise InvitationPermissionDenied(
                "Tenant invitation permission is required."
            ) from None
        if sqlstate == "P0002":
            raise InvitationError("Pending invitation was not found.") from None
        raise


def accept_invitation(
    session: Session,
    *,
    user_id: UUID,
    token: str,
) -> AcceptedInvitation:
    if not token or len(token) > 256:
        raise InvitationError("Invitation token is invalid.")
    try:
        row = session.execute(
            text(
                """
                SELECT tenant_id, membership_id
                  FROM accept_tenant_invitation(:user_id, :token_hash)
                """
            ),
            {"user_id": str(user_id), "token_hash": _token_hash(token)},
        ).mappings().one()
    except DBAPIError as exc:
        sqlstate = getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))
        if sqlstate == "P0002":
            raise InvitationError(
                "Invitation is invalid, expired, already used, or belongs to another email."
            ) from None
        if sqlstate == "42501":
            raise InvitationPermissionDenied(
                "An active global account with a verified email is required."
            ) from None
        if sqlstate == "23505":
            raise InvitationError(
                "An existing membership prevents this invitation from being accepted."
            ) from None
        raise
    return AcceptedInvitation(
        tenant_id=UUID(str(row["tenant_id"])),
        membership_id=UUID(str(row["membership_id"])),
    )
