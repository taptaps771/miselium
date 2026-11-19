"""Global registration and platform-controlled tenant lifecycle services."""
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

from app.backend.security.passwords import hash_password


class RegistrationError(Exception):
    """Registration input conflicts with an existing global identity."""


class VerificationError(Exception):
    """Email verification token is invalid, expired, or already consumed."""


class PlatformPermissionDenied(PermissionError):
    """The global user does not hold the required platform permission."""


class TenantLifecycleError(Exception):
    """Tenant lifecycle transition is invalid."""


@dataclass(frozen=True, slots=True)
class RegistrationChallenge:
    user_id: UUID
    email: str
    raw_token: str
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class TenantRegistration:
    tenant_id: UUID
    tenant_code: str
    tenant_name: str
    location_id: UUID
    membership_id: UUID
    status: str


@dataclass(frozen=True, slots=True)
class PendingTenant:
    tenant_id: UUID
    tenant_code: str
    tenant_name: str
    created_at: datetime


def _normalize_email(email: str) -> str:
    return email.strip().casefold()


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def register_global_user(
    session: Session,
    *,
    email: str,
    password: str,
    display_name: str,
    expires_minutes: int = 30,
) -> RegistrationChallenge:
    normalized = _normalize_email(email)
    if not normalized or len(normalized) > 320:
        raise RegistrationError("A valid email address is required.")
    if not display_name.strip():
        raise RegistrationError("Display name is required.")

    # Serialize concurrent registrations for the same normalized email.
    session.execute(
        text("SELECT pg_advisory_xact_lock(hashtextextended(:email, 0))"),
        {"email": f"miselium:global-email:{normalized}"},
    )
    exists = session.execute(
        text(
            """
            SELECT 1 FROM user_contact_points
             WHERE contact_type = 'email' AND normalized_value = :email
             LIMIT 1
            """
        ),
        {"email": normalized},
    ).first()
    if exists:
        raise RegistrationError("This email cannot be registered.")

    password_hash = hash_password(password)
    user_id = session.execute(
        text(
            """
            INSERT INTO users(status) VALUES ('pending')
            RETURNING id
            """
        )
    ).scalar_one()
    session.execute(
        text(
            """
            INSERT INTO user_profiles(user_id, display_name)
            VALUES (:user_id, :display_name)
            """
        ),
        {"user_id": user_id, "display_name": display_name.strip()},
    )
    session.execute(
        text(
            """
            INSERT INTO user_auth_identities(
                user_id, provider, provider_subject, password_hash, is_primary
            )
            VALUES (:user_id, 'password', :subject, :password_hash, true)
            """
        ),
        {
            "user_id": user_id,
            "subject": str(user_id),
            "password_hash": password_hash,
        },
    )
    contact_id = session.execute(
        text(
            """
            INSERT INTO user_contact_points(
                user_id, contact_type, value, normalized_value,
                is_verified, is_primary
            )
            VALUES (:user_id, 'email', :email, :normalized, false, true)
            RETURNING id
            """
        ),
        {"user_id": user_id, "email": email.strip(), "normalized": normalized},
    ).scalar_one()

    raw_token = secrets.token_urlsafe(32)
    expires_at = datetime.now(UTC) + timedelta(minutes=expires_minutes)
    session.execute(
        text(
            """
            INSERT INTO global_email_verification_challenges(
                user_id, contact_point_id, token_hash, expires_at
            )
            VALUES (:user_id, :contact_id, :token_hash, :expires_at)
            """
        ),
        {
            "user_id": user_id,
            "contact_id": contact_id,
            "token_hash": _token_hash(raw_token),
            "expires_at": expires_at,
        },
    )
    session.execute(
        text(
            """
            INSERT INTO platform_audit_events(
                actor_user_id, action, target_type, target_id, metadata
            )
            VALUES (
                :user_id, 'global_identity.registered', 'global_user', :user_id,
                jsonb_build_object('email', CAST(:email AS text))
            )
            """
        ),
        {"user_id": str(user_id), "email": normalized},
    )
    return RegistrationChallenge(
        user_id=UUID(str(user_id)),
        email=normalized,
        raw_token=raw_token,
        expires_at=expires_at,
    )


def verify_global_email(session: Session, *, token: str) -> UUID:
    if not token or len(token) > 256:
        raise VerificationError("Verification token is invalid.")
    challenge = session.execute(
        text(
            """
            SELECT c.id, c.user_id, c.contact_point_id, c.expires_at,
                   c.consumed_at, u.status
              FROM global_email_verification_challenges AS c
              JOIN users AS u ON u.id = c.user_id
             WHERE c.token_hash = :token_hash
             FOR UPDATE OF c, u
            """
        ),
        {"token_hash": _token_hash(token)},
    ).mappings().one_or_none()
    if (
        challenge is None
        or challenge["consumed_at"] is not None
        or challenge["expires_at"] <= datetime.now(UTC)
        or challenge["status"] not in {"pending", "active"}
    ):
        raise VerificationError("Verification token is invalid or expired.")

    session.execute(
        text(
            """
            UPDATE user_contact_points
               SET is_verified = true, verified_at = now(), is_primary = true
             WHERE id = :contact_id AND user_id = :user_id
            """
        ),
        {
            "contact_id": challenge["contact_point_id"],
            "user_id": challenge["user_id"],
        },
    )
    session.execute(
        text("UPDATE users SET status = 'active' WHERE id = :user_id AND status = 'pending'"),
        {"user_id": challenge["user_id"]},
    )
    session.execute(
        text(
            """
            UPDATE global_email_verification_challenges
               SET consumed_at = now()
             WHERE id = :challenge_id
            """
        ),
        {"challenge_id": challenge["id"]},
    )
    session.execute(
        text(
            """
            INSERT INTO platform_audit_events(
                actor_user_id, action, target_type, target_id, metadata
            )
            VALUES (
                :user_id, 'global_identity.email_verified', 'global_user', :user_id,
                jsonb_build_object('contact_point_id', CAST(:contact_id AS uuid))
            )
            """
        ),
        {
            "user_id": str(challenge["user_id"]),
            "contact_id": str(challenge["contact_point_id"]),
        },
    )
    return UUID(str(challenge["user_id"]))


def request_tenant_registration(
    session: Session,
    *,
    user_id: UUID,
    tenant_code: str,
    tenant_name: str,
    legal_name: str | None,
    location_code: str,
    location_name: str,
    address: str | None,
) -> TenantRegistration:
    code = tenant_code.strip().lower()
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,38}[a-z0-9]", code):
        raise TenantLifecycleError("Tenant code must be 3–40 lowercase letters, digits, or hyphens.")
    if not tenant_name.strip() or not location_name.strip():
        raise TenantLifecycleError("Tenant and primary location names are required.")

    user = session.execute(
        text(
            """
            SELECT u.status
              FROM users AS u
              JOIN user_contact_points AS cp ON cp.user_id = u.id
             WHERE u.id = :user_id
               AND u.status = 'active'
               AND cp.contact_type = 'email'
               AND cp.is_verified IS TRUE
             LIMIT 1
            """
        ),
        {"user_id": str(user_id)},
    ).mappings().one_or_none()
    existing_code = session.execute(
        text("SELECT 1 FROM tenants WHERE code = :code LIMIT 1"),
        {"code": code},
    ).first()
    if existing_code is not None:
        raise TenantLifecycleError("Tenant code is unavailable.")
    if user is None:
        raise TenantLifecycleError("An active user with a verified email is required.")

    tenant_id = session.execute(
        text(
            """
            INSERT INTO tenants(code, name, legal_name, status)
            VALUES (:code, :name, :legal_name, 'pending')
            RETURNING id
            """
        ),
        {
            "code": code,
            "name": tenant_name.strip(),
            "legal_name": legal_name.strip() if legal_name else None,
        },
    ).scalar_one()

    session.execute(
        text("SELECT set_config('app.user_id', :user_id, true)"),
        {"user_id": str(user_id)},
    )
    session.execute(
        text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
        {"tenant_id": str(tenant_id)},
    )
    session.execute(
        text("SELECT ensure_tenant_default_roles(:tenant_id)"),
        {"tenant_id": str(tenant_id)},
    )
    location_id = session.execute(
        text(
            """
            INSERT INTO locations(tenant_id, code, name, address, is_primary, is_active)
            VALUES (:tenant_id, :code, :name, :address, true, true)
            RETURNING id
            """
        ),
        {
            "tenant_id": str(tenant_id),
            "code": location_code.strip().upper(),
            "name": location_name.strip(),
            "address": address,
        },
    ).scalar_one()
    membership_id = session.execute(
        text(
            """
            INSERT INTO tenant_memberships(
                tenant_id, user_id, status, joined_at
            )
            VALUES (:tenant_id, :user_id, 'active', now())
            RETURNING id
            """
        ),
        {"tenant_id": str(tenant_id), "user_id": str(user_id)},
    ).scalar_one()
    owner_role_id = session.execute(
        text(
            """
            SELECT id FROM tenant_roles
             WHERE tenant_id = :tenant_id AND code = 'owner'
            """
        ),
        {"tenant_id": str(tenant_id)},
    ).scalar_one()
    session.execute(
        text(
            """
            INSERT INTO membership_role_assignments(
                tenant_id, membership_id, role_id, assigned_by
            )
            VALUES (:tenant_id, :membership_id, :role_id, :user_id)
            """
        ),
        {
            "tenant_id": str(tenant_id),
            "membership_id": str(membership_id),
            "role_id": str(owner_role_id),
            "user_id": str(user_id),
        },
    )
    session.execute(
        text(
            """
            INSERT INTO membership_location_scopes(tenant_id, membership_id, location_id)
            VALUES (:tenant_id, :membership_id, :location_id)
            """
        ),
        {
            "tenant_id": str(tenant_id),
            "membership_id": str(membership_id),
            "location_id": str(location_id),
        },
    )
    session.execute(
        text(
            """
            INSERT INTO platform_audit_events(
                actor_user_id, action, target_type, target_id, reason, metadata
            )
            VALUES (
                :user_id, 'tenant.registration_requested', 'tenant', :tenant_id,
                'Self-service tenant registration', jsonb_build_object('tenant_code', CAST(:code AS text))
            )
            """
        ),
        {"user_id": str(user_id), "tenant_id": str(tenant_id), "code": code},
    )
    return TenantRegistration(
        tenant_id=UUID(str(tenant_id)),
        tenant_code=code,
        tenant_name=tenant_name.strip(),
        location_id=UUID(str(location_id)),
        membership_id=UUID(str(membership_id)),
        status="pending",
    )


def require_platform_permission(
    session: Session,
    *,
    user_id: UUID,
    permission_code: str,
) -> None:
    session.execute(
        text("SELECT set_config('app.user_id', :user_id, true)"),
        {"user_id": str(user_id)},
    )
    granted = session.execute(
        text(
            """
            SELECT 1
              FROM platform_user_roles AS ur
              JOIN users AS u ON u.id = ur.user_id AND u.status = 'active'
              JOIN platform_role_permissions AS rp ON rp.role_id = ur.role_id
              JOIN platform_permissions AS p ON p.id = rp.permission_id
             WHERE ur.user_id = :user_id AND p.code = :permission
             LIMIT 1
            """
        ),
        {"user_id": str(user_id), "permission": permission_code},
    ).first()
    if granted is None:
        raise PlatformPermissionDenied("Required platform permission is missing.")


def list_pending_tenants(session: Session) -> tuple[PendingTenant, ...]:
    rows = session.execute(
        text(
            """
            SELECT id, code, name, created_at
              FROM tenants
             WHERE status = 'pending'
             ORDER BY created_at, code
            """
        )
    ).mappings().all()
    return tuple(
        PendingTenant(
            tenant_id=UUID(str(row["id"])),
            tenant_code=str(row["code"]),
            tenant_name=str(row["name"]),
            created_at=row["created_at"],
        )
        for row in rows
    )


def approve_tenant_registration(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    reason: str,
) -> None:
    if not reason.strip():
        raise TenantLifecycleError("An approval reason is required.")
    session.execute(
        text("SELECT set_config('app.user_id', :user_id, true)"),
        {"user_id": str(actor_user_id)},
    )
    require_platform_permission(
        session,
        user_id=actor_user_id,
        permission_code="platform.tenants.approve",
    )
    try:
        session.execute(
            text(
                """
                SELECT tenant_id, tenant_code, tenant_name
                  FROM platform_approve_pending_tenant(
                    :actor_user_id, :tenant_id, :reason
                  )
                """
            ),
            {
                "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id),
                "reason": reason.strip(),
            },
        ).mappings().one()
    except DBAPIError as exc:
        sqlstate = getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))
        if sqlstate == "P0002":
            raise TenantLifecycleError(
                "Tenant is not pending or does not exist."
            ) from None
        if sqlstate == "42501":
            raise PlatformPermissionDenied(
                "Required platform permission is missing."
            ) from None
        raise
