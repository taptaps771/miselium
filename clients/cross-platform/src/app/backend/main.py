"""Miselium SaaS API application factory with enforced tenant membership checks."""

from __future__ import annotations

import hashlib
import os
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime

import jwt
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.backend.db.models import (
    Base,
    DeviceRegistration,
    Membership,
    Tenant,
    TenantInvitation,
    TenantRecord,
    User,
)
from app.backend.db.session import build_engine, build_session_factory
from app.backend.schemas import (
    DeviceRegistrationRequest,
    InvitationAccept,
    InvitationCreate,
    LoginRequest,
    RecordCreate,
    RecordResponse,
    RegisterRequest,
    TokenResponse,
)
from app.backend.security.passwords import hash_password, verify_password
from app.backend.security.tokens import create_access_token, decode_access_token


@dataclass(frozen=True, slots=True)
class Principal:
    user: User
    tenant: Tenant
    membership: Membership


bearer = HTTPBearer(auto_error=False)
PLAN_LIMITS: dict[str, int | None] = {"free": 100, "pro": 5000, "enterprise": None}


def _record_count(db: Session, tenant_id: str) -> int:
    return db.scalar(
        select(func.count(TenantRecord.id)).where(TenantRecord.tenant_id == tenant_id)
    ) or 0


def _invitation_is_expired(invitation: TenantInvitation) -> bool:
    expires_at = invitation.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    return expires_at <= datetime.now(UTC)


def create_app(*, database_url: str | None = None, create_schema: bool = False) -> FastAPI:
    engine = build_engine(database_url)
    session_factory = build_session_factory(engine)
    if create_schema:
        Base.metadata.create_all(engine)

    application = FastAPI(
        title="Miselium API",
        version="0.8.0",
        description="Multi-tenant SaaS API for Miselium clients.",
        docs_url=None if os.getenv("MISELIUM_ENVIRONMENT") == "production" else "/docs",
        redoc_url=None if os.getenv("MISELIUM_ENVIRONMENT") == "production" else "/redoc",
    )
    application.state.engine = engine
    application.state.session_factory = session_factory

    def db_session():
        with session_factory() as session:
            yield session

    def authenticated(
        credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
        db: Session = Depends(db_session),
    ) -> Principal:
        unauthorized = HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        if credentials is None:
            raise unauthorized
        try:
            claims = decode_access_token(credentials.credentials)
            user_id = str(claims["sub"])
            tenant_id = str(claims["tid"])
        except (jwt.InvalidTokenError, KeyError, TypeError, RuntimeError):
            raise unauthorized from None

        user = db.get(User, user_id)
        tenant = db.get(Tenant, tenant_id)
        membership = db.scalar(
            select(Membership).where(
                Membership.user_id == user_id,
                Membership.tenant_id == tenant_id,
            )
        )
        if (
            user is None
            or not user.is_active
            or tenant is None
            or not tenant.is_active
            or membership is None
        ):
            raise unauthorized
        return Principal(user=user, tenant=tenant, membership=membership)

    @application.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "service": "miselium-api"}

    @application.post("/v1/auth/register", response_model=TokenResponse, status_code=201)
    def register(
        payload: RegisterRequest,
        db: Session = Depends(db_session),
    ) -> TokenResponse:
        email = str(payload.email).lower()
        if db.scalar(select(User.id).where(User.email == email)):
            raise HTTPException(status_code=409, detail="Email is already registered.")
        if db.scalar(select(Tenant.id).where(Tenant.slug == payload.tenant_slug)):
            raise HTTPException(status_code=409, detail="Tenant slug is already in use.")

        try:
            user = User(
                email=email,
                password_hash=hash_password(payload.password),
                display_name=payload.display_name,
            )
            tenant = Tenant(name=payload.tenant_name, slug=payload.tenant_slug)
            db.add_all([user, tenant])
            db.flush()
            membership = Membership(user_id=user.id, tenant_id=tenant.id, role="owner")
            db.add(membership)
            # Validate signing configuration before committing the new account.
            token = create_access_token(
                user_id=user.id,
                tenant_id=tenant.id,
                role=membership.role,
            )
            db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(
                status_code=409,
                detail="Email or tenant slug is already in use.",
            ) from None
        return TokenResponse(access_token=token, tenant_id=tenant.id, role=membership.role)

    @application.post("/v1/auth/login", response_model=TokenResponse)
    def login(
        payload: LoginRequest,
        db: Session = Depends(db_session),
    ) -> TokenResponse:
        user = db.scalar(select(User).where(User.email == str(payload.email).lower()))
        tenant = db.scalar(select(Tenant).where(Tenant.slug == payload.tenant_slug))
        if (
            user is None
            or not user.is_active
            or tenant is None
            or not tenant.is_active
            or not verify_password(payload.password, user.password_hash)
        ):
            raise HTTPException(
                status_code=401,
                detail="Email, password, or workspace is invalid.",
            )

        membership = db.scalar(
            select(Membership).where(
                Membership.user_id == user.id,
                Membership.tenant_id == tenant.id,
            )
        )
        if membership is None:
            raise HTTPException(
                status_code=401,
                detail="Email, password, or workspace is invalid.",
            )
        token = create_access_token(
            user_id=user.id,
            tenant_id=tenant.id,
            role=membership.role,
        )
        return TokenResponse(access_token=token, tenant_id=tenant.id, role=membership.role)

    @application.get("/v1/me")
    def me(principal: Principal = Depends(authenticated)) -> dict[str, object]:
        return {
            "user": {
                "id": principal.user.id,
                "email": principal.user.email,
                "display_name": principal.user.display_name,
            },
            "tenant": {
                "id": principal.tenant.id,
                "slug": principal.tenant.slug,
                "name": principal.tenant.name,
                "plan": principal.tenant.plan,
            },
            "role": principal.membership.role,
        }

    @application.get("/v1/tenants")
    def tenants(
        principal: Principal = Depends(authenticated),
        db: Session = Depends(db_session),
    ) -> list[dict[str, str]]:
        rows = db.execute(
            select(Tenant, Membership.role)
            .join(Membership, Membership.tenant_id == Tenant.id)
            .where(
                Membership.user_id == principal.user.id,
                Tenant.is_active.is_(True),
            )
            .order_by(Tenant.name)
        ).all()
        return [
            {"id": tenant.id, "slug": tenant.slug, "name": tenant.name, "role": role}
            for tenant, role in rows
        ]

    @application.post("/v1/records", response_model=RecordResponse, status_code=201)
    def create_record(
        payload: RecordCreate,
        principal: Principal = Depends(authenticated),
        db: Session = Depends(db_session),
    ) -> TenantRecord:
        limit = PLAN_LIMITS.get(principal.tenant.plan, PLAN_LIMITS["free"])
        if limit is not None and _record_count(db, principal.tenant.id) >= limit:
            raise HTTPException(
                status_code=402,
                detail="Workspace plan quota has been reached.",
            )
        record = TenantRecord(
            tenant_id=principal.tenant.id,
            created_by=principal.user.id,
            title=payload.title,
            payload=payload.payload,
        )
        db.add(record)
        db.commit()
        db.refresh(record)
        return record

    @application.get("/v1/records", response_model=list[RecordResponse])
    def list_records(
        principal: Principal = Depends(authenticated),
        db: Session = Depends(db_session),
    ) -> list[TenantRecord]:
        records = db.scalars(
            select(TenantRecord)
            .where(TenantRecord.tenant_id == principal.tenant.id)
            .order_by(TenantRecord.created_at.desc())
            .limit(500)
        )
        return list(records.all())

    @application.get("/v1/records/{record_id}", response_model=RecordResponse)
    def get_record(
        record_id: str,
        principal: Principal = Depends(authenticated),
        db: Session = Depends(db_session),
    ) -> TenantRecord:
        record = db.scalar(
            select(TenantRecord).where(
                TenantRecord.id == record_id,
                TenantRecord.tenant_id == principal.tenant.id,
            )
        )
        if record is None:
            raise HTTPException(status_code=404, detail="Record not found.")
        return record

    @application.get("/v1/usage")
    def tenant_usage(
        principal: Principal = Depends(authenticated),
        db: Session = Depends(db_session),
    ) -> dict[str, object]:
        limit = PLAN_LIMITS.get(principal.tenant.plan, PLAN_LIMITS["free"])
        used = _record_count(db, principal.tenant.id)
        remaining = None if limit is None else max(0, limit - used)
        return {
            "plan": principal.tenant.plan,
            "records_used": used,
            "records_limit": limit,
            "remaining": remaining,
        }

    @application.post("/v1/invitations", status_code=201)
    def create_invitation(
        payload: InvitationCreate,
        principal: Principal = Depends(authenticated),
        db: Session = Depends(db_session),
    ) -> dict[str, object]:
        if principal.membership.role not in {"owner", "admin"}:
            raise HTTPException(
                status_code=403,
                detail="Workspace administrator role required.",
            )
        email = str(payload.email).lower()
        existing_user = db.scalar(select(User).where(User.email == email))
        if existing_user and db.scalar(
            select(Membership.id).where(
                Membership.user_id == existing_user.id,
                Membership.tenant_id == principal.tenant.id,
            )
        ):
            raise HTTPException(status_code=409, detail="User is already a workspace member.")
        pending = db.scalar(
            select(TenantInvitation.id).where(
                TenantInvitation.tenant_id == principal.tenant.id,
                TenantInvitation.email == email,
                TenantInvitation.accepted_at.is_(None),
            )
        )
        if pending:
            raise HTTPException(
                status_code=409,
                detail="A pending invitation already exists for this email.",
            )

        raw_token = secrets.token_urlsafe(36)
        invitation = TenantInvitation(
            tenant_id=principal.tenant.id,
            email=email,
            role=payload.role,
            token_hash=hashlib.sha256(raw_token.encode()).hexdigest(),
        )
        db.add(invitation)
        db.commit()
        result: dict[str, object] = {
            "invitation_id": invitation.id,
            "status": "delivery_pending",
            "expires_at": invitation.expires_at.isoformat(),
        }
        # A mail provider is intentionally not fabricated.
        if os.getenv("MISELIUM_ENVIRONMENT", "development") != "production":
            result["development_token"] = raw_token
        return result

    @application.post("/v1/invitations/accept")
    def accept_invitation(
        payload: InvitationAccept,
        principal: Principal = Depends(authenticated),
        db: Session = Depends(db_session),
    ) -> dict[str, str]:
        token_hash = hashlib.sha256(payload.invitation_token.encode()).hexdigest()
        invitation = db.scalar(
            select(TenantInvitation)
            .where(TenantInvitation.token_hash == token_hash)
            .with_for_update()
        )
        if (
            invitation is None
            or invitation.accepted_at is not None
            or _invitation_is_expired(invitation)
        ):
            raise HTTPException(
                status_code=400,
                detail="Invitation is invalid, expired, or already used.",
            )
        if invitation.email != principal.user.email:
            raise HTTPException(
                status_code=403,
                detail="Invitation email does not match the signed-in account.",
            )
        membership_exists = db.scalar(
            select(Membership.id).where(
                Membership.user_id == principal.user.id,
                Membership.tenant_id == invitation.tenant_id,
            )
        )
        if membership_exists:
            raise HTTPException(status_code=409, detail="User is already a workspace member.")

        db.add(
            Membership(
                user_id=principal.user.id,
                tenant_id=invitation.tenant_id,
                role=invitation.role,
            )
        )
        invitation.accepted_at = datetime.now(UTC)
        db.commit()
        return {
            "status": "accepted",
            "tenant_id": invitation.tenant_id,
            "role": invitation.role,
        }

    @application.post("/v1/devices", status_code=201)
    def register_device(
        payload: DeviceRegistrationRequest,
        principal: Principal = Depends(authenticated),
        db: Session = Depends(db_session),
    ) -> dict[str, str]:
        device = db.scalar(
            select(DeviceRegistration).where(
                DeviceRegistration.tenant_id == principal.tenant.id,
                DeviceRegistration.user_id == principal.user.id,
                DeviceRegistration.device_id == payload.device_id,
            )
        )
        if device is None:
            device = DeviceRegistration(
                tenant_id=principal.tenant.id,
                user_id=principal.user.id,
                device_id=payload.device_id,
                platform=payload.platform,
                push_token=payload.push_token,
            )
            db.add(device)
        else:
            device.platform = payload.platform
            device.push_token = payload.push_token
            device.is_active = True
        db.commit()
        return {"status": "registered", "device_id": payload.device_id}

    return application


app = create_app()
