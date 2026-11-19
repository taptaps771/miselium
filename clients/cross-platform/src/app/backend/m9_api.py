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
from app.backend.services.authentication import (
    authenticate_global_user,
    authorize_tenant_context,
)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=256)


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

    def db_session() -> Generator[Session, None, None]:
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
