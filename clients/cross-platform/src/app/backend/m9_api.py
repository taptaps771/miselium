"""Canonical M9 authentication API.

Run with an explicit PostgreSQL DSN using an ASGI factory, for example:
    uvicorn app.backend.m9_api:create_m9_app --factory
This API does not import or create the legacy M7 ORM schema.
"""
from __future__ import annotations

import os
from collections.abc import Callable, Generator
from typing import Any
from uuid import UUID

import jwt
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session, sessionmaker

from app.backend.db.session import build_engine, build_session_factory
from app.backend.m9_identity import (
    IdentityResolutionError,
    M9IdentityRepository,
    TenantAccessDenied,
)
from app.backend.security.m9_tokens import (
    create_m9_access_token,
    create_tenant_selection_token,
    decode_m9_access_token,
    decode_tenant_selection_token,
)
from app.backend.services.tenant_lifecycle import (
    PlatformPermissionDenied,
    RegistrationError,
    TenantLifecycleError,
    VerificationError,
    approve_tenant_registration,
    list_pending_tenants,
    register_global_user,
    request_tenant_registration,
    verify_global_email,
)
from app.backend.services.authentication import (
    authenticate_global_user,
    authorize_tenant_context,
)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=256)


class RegistrationRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12, max_length=256)
    display_name: str = Field(min_length=1, max_length=160)


class VerifyEmailRequest(BaseModel):
    token: str = Field(min_length=20, max_length=256)


class TenantRegistrationRequest(BaseModel):
    code: str = Field(min_length=3, max_length=40)
    name: str = Field(min_length=1, max_length=180)
    legal_name: str | None = Field(default=None, max_length=220)
    primary_location_code: str = Field(default="MAIN", min_length=1, max_length=50)
    primary_location_name: str = Field(default="Lokasi Utama", min_length=1, max_length=150)
    primary_location_address: str | None = None


class TenantApprovalRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=1000)


class RegistrationAcceptedResponse(BaseModel):
    status: str = "verification_required"
    message: str = "Check your email for the verification link."


class EmailVerifiedResponse(BaseModel):
    status: str = "verified"
    selection_token: str
    token_type: str = "bearer"
    expires_in: int = 300


class TenantRegistrationResponse(BaseModel):
    tenant_id: UUID
    code: str
    name: str
    status: str
    location_id: UUID
    membership_id: UUID


class PendingTenantResponse(BaseModel):
    tenant_id: UUID
    code: str
    name: str
    created_at: Any


class SelectTenantRequest(BaseModel):
    tenant_id: UUID


class TenantOptionResponse(BaseModel):
    tenant_id: UUID
    membership_id: UUID
    code: str
    name: str


class GlobalLoginResponse(BaseModel):
    selection_token: str
    token_type: str = "bearer"
    expires_in: int = 300
    tenants: list[TenantOptionResponse]


class TenantAccessResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 1800
    tenant_id: UUID
    tenant_code: str
    tenant_name: str
    permissions: list[str]


class CurrentUserResponse(BaseModel):
    user_id: UUID
    tenant_id: UUID
    membership_id: UUID
    tenant_code: str
    tenant_name: str
    permissions: list[str]


bearer = HTTPBearer(auto_error=False)
RepositoryFactory = Callable[[Session], M9IdentityRepository]


def create_m9_app(
    *,
    database_url: str | None = None,
    session_factory: sessionmaker[Session] | None = None,
    repository_factory: RepositoryFactory = M9IdentityRepository,
    verification_sender: Callable[[str, str], None] | None = None,
) -> FastAPI:
    """Build M9 API; require PostgreSQL and never fall back to the M7 SQLite DB."""
    if session_factory is None:
        dsn = database_url or os.getenv("MISELIUM_DATABASE_URL", "")
        if not dsn.startswith(("postgresql://", "postgresql+psycopg://")):
            raise RuntimeError("M9 API requires a PostgreSQL MISELIUM_DATABASE_URL")
        session_factory = build_session_factory(build_engine(dsn))

    application = FastAPI(
        title="Miselium M9 Identity API",
        version="0.9.0",
        description="Global identity authentication and tenant-scoped authorization.",
    )
    application.state.session_factory = session_factory

    def db_session() -> Generator[Session]:
        with session_factory() as session:
            try:
                yield session
                session.commit()
            except Exception:
                session.rollback()
                raise

    def selection_user(
        credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    ) -> UUID:
        if credentials is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Tenant selection session is required.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        try:
            return decode_tenant_selection_token(credentials.credentials)
        except (jwt.InvalidTokenError, ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Tenant selection session is invalid or expired.",
                headers={"WWW-Authenticate": "Bearer"},
            ) from None

    def access_context(
        credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
        db: Session = Depends(db_session),
    ) -> tuple[UUID, UUID, Any]:
        if credentials is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Access token is required.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        try:
            user_id, tenant_id = decode_m9_access_token(credentials.credentials)
        except (jwt.InvalidTokenError, ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Access token is invalid or expired.",
                headers={"WWW-Authenticate": "Bearer"},
            ) from None
        repository = repository_factory(db)
        try:
            authorization = authorize_tenant_context(
                repository,
                user_id=user_id,
                tenant_id=tenant_id,
            )
        except TenantAccessDenied:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Access token is invalid or tenant access is no longer active.",
                headers={"WWW-Authenticate": "Bearer"},
            ) from None
        return user_id, tenant_id, authorization

    @application.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "service": "miselium-m9-identity-api"}

    @application.post(
        "/v1/auth/register",
        response_model=RegistrationAcceptedResponse,
        status_code=status.HTTP_202_ACCEPTED,
    )
    def register(
        payload: RegistrationRequest,
        db: Session = Depends(db_session),
    ) -> RegistrationAcceptedResponse:
        if verification_sender is None:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Email verification delivery is not configured.",
            )
        try:
            challenge = register_global_user(
                db,
                email=str(payload.email),
                password=payload.password,
                display_name=payload.display_name,
            )
            verification_sender(challenge.email, challenge.raw_token)
        except RegistrationError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from None
        except (ValueError, RuntimeError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Registration could not be completed.",
            ) from None
        return RegistrationAcceptedResponse()

    @application.post("/v1/auth/verify-email", response_model=EmailVerifiedResponse)
    def verify_email(
        payload: VerifyEmailRequest,
        db: Session = Depends(db_session),
    ) -> EmailVerifiedResponse:
        try:
            user_id = verify_global_email(db, token=payload.token)
        except VerificationError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Verification token is invalid or expired.",
            ) from None
        return EmailVerifiedResponse(
            selection_token=create_tenant_selection_token(user_id=user_id)
        )

    @application.post(
        "/v1/tenants",
        response_model=TenantRegistrationResponse,
        status_code=status.HTTP_201_CREATED,
    )
    def create_tenant_request(
        payload: TenantRegistrationRequest,
        user_id: UUID = Depends(selection_user),
        db: Session = Depends(db_session),
    ) -> TenantRegistrationResponse:
        try:
            result = request_tenant_registration(
                db,
                user_id=user_id,
                tenant_code=payload.code,
                tenant_name=payload.name,
                legal_name=payload.legal_name,
                location_code=payload.primary_location_code,
                location_name=payload.primary_location_name,
                address=payload.primary_location_address,
            )
        except TenantLifecycleError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from None
        return TenantRegistrationResponse(
            tenant_id=result.tenant_id,
            code=result.tenant_code,
            name=result.tenant_name,
            status=result.status,
            location_id=result.location_id,
            membership_id=result.membership_id,
        )

    @application.get(
        "/v1/platform/tenants/pending",
        response_model=list[PendingTenantResponse],
    )
    def pending_tenants(
        user_id: UUID = Depends(selection_user),
        db: Session = Depends(db_session),
    ) -> list[PendingTenantResponse]:
        from app.backend.services.tenant_lifecycle import require_platform_permission

        try:
            require_platform_permission(
                db,
                user_id=user_id,
                permission_code="platform.tenants.approve",
            )
        except PlatformPermissionDenied:
            raise HTTPException(status_code=403, detail="Platform permission required.") from None
        return [
            PendingTenantResponse(
                tenant_id=item.tenant_id,
                code=item.tenant_code,
                name=item.tenant_name,
                created_at=item.created_at,
            )
            for item in list_pending_tenants(db)
        ]

    @application.post("/v1/platform/tenants/{tenant_id}/approve", status_code=204)
    def approve_tenant(
        tenant_id: UUID,
        payload: TenantApprovalRequest,
        user_id: UUID = Depends(selection_user),
        db: Session = Depends(db_session),
    ) -> None:
        try:
            approve_tenant_registration(
                db,
                actor_user_id=user_id,
                tenant_id=tenant_id,
                reason=payload.reason,
            )
        except PlatformPermissionDenied:
            raise HTTPException(status_code=403, detail="Platform permission required.") from None
        except TenantLifecycleError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from None

    @application.post("/v1/auth/login", response_model=GlobalLoginResponse)
    def global_login(
        payload: LoginRequest,
        db: Session = Depends(db_session),
    ) -> GlobalLoginResponse:
        try:
            result = authenticate_global_user(
                repository_factory(db),
                email=str(payload.email),
                password=payload.password,
            )
        except IdentityResolutionError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Email or password is invalid.",
                headers={"WWW-Authenticate": "Bearer"},
            ) from None
        return GlobalLoginResponse(
            selection_token=create_tenant_selection_token(
                user_id=result.identity.user_id
            ),
            tenants=[
                TenantOptionResponse(
                    tenant_id=tenant.tenant_id,
                    membership_id=tenant.membership_id,
                    code=tenant.tenant_code,
                    name=tenant.tenant_name,
                )
                for tenant in result.active_tenants
            ],
        )

    @application.get("/v1/auth/tenants", response_model=list[TenantOptionResponse])
    def list_tenants(
        user_id: UUID = Depends(selection_user),
        db: Session = Depends(db_session),
    ) -> list[TenantOptionResponse]:
        # The token is issued only after global password verification.
        repository = repository_factory(db)
        tenants = repository.list_active_tenants(user_id)
        return [
            TenantOptionResponse(
                tenant_id=tenant.tenant_id,
                membership_id=tenant.membership_id,
                code=tenant.tenant_code,
                name=tenant.tenant_name,
            )
            for tenant in tenants
        ]

    @application.post("/v1/auth/select-tenant", response_model=TenantAccessResponse)
    def select_tenant(
        payload: SelectTenantRequest,
        user_id: UUID = Depends(selection_user),
        db: Session = Depends(db_session),
    ) -> TenantAccessResponse:
        try:
            authorization = authorize_tenant_context(
                repository_factory(db),
                user_id=user_id,
                tenant_id=payload.tenant_id,
            )
        except TenantAccessDenied:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No active membership grants access to this tenant.",
            ) from None
        principal = authorization.principal
        return TenantAccessResponse(
            access_token=create_m9_access_token(
                user_id=user_id,
                tenant_id=payload.tenant_id,
            ),
            tenant_id=principal.tenant_id,
            tenant_code=principal.tenant_code,
            tenant_name=principal.tenant_name,
            permissions=sorted(authorization.permissions),
        )

    @application.get("/v1/me", response_model=CurrentUserResponse)
    def current_user(
        context: tuple[UUID, UUID, Any] = Depends(access_context),
    ) -> CurrentUserResponse:
        user_id, tenant_id, authorization = context
        principal = authorization.principal
        return CurrentUserResponse(
            user_id=user_id,
            tenant_id=tenant_id,
            membership_id=principal.membership_id,
            tenant_code=principal.tenant_code,
            tenant_name=principal.tenant_name,
            permissions=sorted(authorization.permissions),
        )

    return application
