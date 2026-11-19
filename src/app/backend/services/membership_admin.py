"""Tenant membership administration services backed by PostgreSQL functions."""
from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session


class MembershipAdminError(Exception):
    """Membership administration request or transition is invalid."""


class MembershipAdminPermissionDenied(PermissionError):
    """Actor cannot administer or read tenant memberships."""


@dataclass(frozen=True, slots=True)
class TenantMember:
    membership_id: UUID
    user_id: UUID
    display_name: str | None
    email: str | None
    status: str
    joined_at: object | None
    roles: tuple[str, ...]


def _sqlstate(exc: DBAPIError) -> str | None:
    return getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))


def _set_actor(session: Session, actor_user_id: UUID) -> None:
    session.execute(
        text("SELECT set_config('app.user_id', :user_id, true)"),
        {"user_id": str(actor_user_id)},
    )


def list_tenant_members(
    session: Session, *, actor_user_id: UUID, tenant_id: UUID
) -> tuple[TenantMember, ...]:
    _set_actor(session, actor_user_id)
    try:
        rows = session.execute(
            text(
                """
                SELECT membership_id, user_id, display_name, email,
                       membership_status, joined_at, role_codes
                  FROM list_tenant_members(:actor_user_id, :tenant_id)
                """
            ),
            {"actor_user_id": str(actor_user_id), "tenant_id": str(tenant_id)},
        ).mappings().all()
    except DBAPIError as exc:
        if _sqlstate(exc) == "42501":
            raise MembershipAdminPermissionDenied(
                "Tenant membership read permission is required."
            ) from None
        raise
    return tuple(
        TenantMember(
            membership_id=UUID(str(row["membership_id"])),
            user_id=UUID(str(row["user_id"])),
            display_name=row["display_name"],
            email=row["email"],
            status=str(row["membership_status"]),
            joined_at=row["joined_at"],
            roles=tuple(row["role_codes"] or ()),
        )
        for row in rows
    )


def change_member_role(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    membership_id: UUID,
    role_code: str,
    reason: str | None = None,
) -> None:
    role = role_code.strip().lower()
    if not role or len(role) > 60 or role == "owner":
        raise MembershipAdminError("The requested role cannot be assigned.")
    role_id = session.execute(
        text("SELECT id FROM tenant_roles WHERE tenant_id=:tenant_id AND code=:code"),
        {"tenant_id": str(tenant_id), "code": role},
    ).scalar_one_or_none()
    if role_id is None:
        raise MembershipAdminError("The requested tenant role does not exist.")
    _set_actor(session, actor_user_id)
    try:
        session.execute(
            text(
                """
                SELECT set_tenant_member_role(
                    :actor_user_id, :tenant_id, :membership_id, :role_id, :reason
                )
                """
            ),
            {
                "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id),
                "membership_id": str(membership_id),
                "role_id": str(role_id),
                "reason": reason,
            },
        )
    except DBAPIError as exc:
        state = _sqlstate(exc)
        if state == "42501":
            raise MembershipAdminPermissionDenied(
                "Tenant membership management permission is required."
            ) from None
        if state in {"P0002", "22023", "23514"}:
            raise MembershipAdminError(
                "The requested role change is invalid for this membership."
            ) from None
        raise


def transition_member(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    membership_id: UUID,
    action: str,
    reason: str | None = None,
) -> None:
    if action not in {"suspend", "reactivate", "remove"}:
        raise MembershipAdminError("Unsupported membership action.")
    _set_actor(session, actor_user_id)
    try:
        session.execute(
            text(
                """
                SELECT transition_tenant_member(
                    :actor_user_id, :tenant_id, :membership_id, :action, :reason
                )
                """
            ),
            {
                "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id),
                "membership_id": str(membership_id),
                "action": action,
                "reason": reason,
            },
        )
    except DBAPIError as exc:
        state = _sqlstate(exc)
        if state == "42501":
            raise MembershipAdminPermissionDenied(
                "Tenant membership management permission is required."
            ) from None
        if state in {"P0002", "22023", "23514"}:
            raise MembershipAdminError(
                "The requested membership transition is invalid."
            ) from None
        raise
