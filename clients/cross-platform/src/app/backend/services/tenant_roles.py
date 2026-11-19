"""Tenant-scoped custom role and permission administration."""
from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session


class TenantRoleError(Exception):
    """Custom role or permission update is invalid."""


class TenantRolePermissionDenied(PermissionError):
    """Actor cannot read or manage tenant roles."""


@dataclass(frozen=True, slots=True)
class TenantRole:
    role_id: UUID
    code: str
    name: str
    is_system: bool
    permissions: tuple[str, ...]
    member_count: int


@dataclass(frozen=True, slots=True)
class TenantPermission:
    code: str
    description: str | None
    actor_can_grant: bool


def _sqlstate(exc: DBAPIError) -> str | None:
    return getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))


def _set_actor(session: Session, actor_user_id: UUID) -> None:
    session.execute(
        text("SELECT set_config('app.user_id', :user_id, true)"),
        {"user_id": str(actor_user_id)},
    )


def _raise_db_error(exc: DBAPIError) -> None:
    state = _sqlstate(exc)
    if state == "42501":
        raise TenantRolePermissionDenied("Tenant role permission is required.") from None
    if state in {"P0002", "22023", "23505"}:
        raise TenantRoleError("The requested tenant role operation is invalid.") from None
    raise exc


def list_roles(
    session: Session, *, actor_user_id: UUID, tenant_id: UUID
) -> tuple[TenantRole, ...]:
    _set_actor(session, actor_user_id)
    try:
        rows = session.execute(
            text("""
                SELECT role_id, role_code, role_name, is_system, permission_codes, member_count
                  FROM list_tenant_roles(:actor_user_id, :tenant_id)
            """),
            {"actor_user_id": str(actor_user_id), "tenant_id": str(tenant_id)},
        ).mappings().all()
    except DBAPIError as exc:
        _raise_db_error(exc)
    return tuple(
        TenantRole(
            role_id=UUID(str(row["role_id"])),
            code=str(row["role_code"]),
            name=str(row["role_name"]),
            is_system=bool(row["is_system"]),
            permissions=tuple(row["permission_codes"] or ()),
            member_count=int(row["member_count"]),
        )
        for row in rows
    )


def list_permission_catalog(
    session: Session, *, actor_user_id: UUID, tenant_id: UUID
) -> tuple[TenantPermission, ...]:
    _set_actor(session, actor_user_id)
    try:
        rows = session.execute(
            text("""
                SELECT permission_code, description, actor_can_grant
                  FROM list_tenant_permission_catalog(:actor_user_id, :tenant_id)
            """),
            {"actor_user_id": str(actor_user_id), "tenant_id": str(tenant_id)},
        ).mappings().all()
    except DBAPIError as exc:
        _raise_db_error(exc)
    return tuple(
        TenantPermission(
            code=str(row["permission_code"]),
            description=row["description"],
            actor_can_grant=bool(row["actor_can_grant"]),
        )
        for row in rows
    )


def create_role(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    code: str,
    name: str,
    reason: str | None = None,
) -> UUID:
    _set_actor(session, actor_user_id)
    try:
        role_id = session.execute(
            text("""
                SELECT create_tenant_role(
                    :actor_user_id, :tenant_id, :code, :name, :reason
                )
            """),
            {
                "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id),
                "code": code.strip().lower(),
                "name": name.strip(),
                "reason": reason,
            },
        ).scalar_one()
    except DBAPIError as exc:
        _raise_db_error(exc)
    return UUID(str(role_id))


def set_role_permissions(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    role_id: UUID,
    permission_codes: list[str],
    reason: str | None = None,
) -> None:
    _set_actor(session, actor_user_id)
    try:
        session.execute(
            text("""
                SELECT set_tenant_role_permissions(
                    :actor_user_id, :tenant_id, :role_id, :permission_codes, :reason
                )
            """),
            {
                "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id),
                "role_id": str(role_id),
                "permission_codes": permission_codes,
                "reason": reason,
            },
        )
    except DBAPIError as exc:
        _raise_db_error(exc)
