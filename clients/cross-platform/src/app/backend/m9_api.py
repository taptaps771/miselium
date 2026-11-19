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
from app.backend.services.invitations import (
    InvitationError,
    InvitationPermissionDenied,
    accept_invitation,
    create_invitation,
    list_invitations,
    revoke_invitation,
)
from app.backend.services.membership_admin import (
    MembershipAdminError,
    MembershipAdminPermissionDenied,
    change_member_role,
    list_tenant_members,
    transition_member,
)
from app.backend.services.authentication import (
    authenticate_global_user,
    authorize_tenant_context,
)
from app.backend.services.tenant_roles import (
    TenantRoleError,
    TenantRolePermissionDenied,
    create_role,
    list_permission_catalog,
    list_roles,
    set_role_permissions,
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


class InvitationCreateRequest(BaseModel):
    email: EmailStr
    role_code: str = Field(default="member", min_length=2, max_length=60)
    expires_days: int = Field(default=7, ge=1, le=30)


class InvitationRevokeRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=1000)


class InvitationAcceptRequest(BaseModel):
    token: str = Field(min_length=20, max_length=256)


class InvitationResponse(BaseModel):
    invitation_id: UUID
    tenant_id: UUID
    email: EmailStr
    role_code: str
    status: str
    expires_at: Any


class InvitationListItemResponse(BaseModel):
    invitation_id: UUID
    email: EmailStr
    status: str
    role_code: str
    expires_at: Any
    created_at: Any


class InvitationAcceptedResponse(BaseModel):
    status: str = "accepted"
    tenant_id: UUID
    membership_id: UUID


class MemberRoleRequest(BaseModel):
    role_code: str = Field(min_length=2, max_length=60)
    reason: str | None = Field(default=None, max_length=1000)


class MemberActionRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=1000)


class TenantMemberResponse(BaseModel):
    membership_id: UUID
    user_id: UUID
    display_name: str | None
    email: str | None
    status: str
    joined_at: Any | None
    roles: list[str]

class TenantRoleCreateRequest(BaseModel):
    code: str = Field(min_length=2, max_length=60, pattern=r"^[a-z][a-z0-9_-]{1,59}$")
    name: str = Field(min_length=1, max_length=120)
    reason: str | None = Field(default=None, max_length=1000)


class TenantRoleResponse(BaseModel):
    role_id: UUID
    code: str
    name: str
    is_system: bool
    permissions: list[str]
    member_count: int


class TenantPermissionResponse(BaseModel):
    code: str
    description: str | None
    actor_can_grant: bool


class TenantRolePermissionsRequest(BaseModel):
    permission_codes: list[str] = Field(max_length=300)
    reason: str | None = Field(default=None, max_length=1000)



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
    invitation_sender: Callable[[str, str, str], None] | None = None,
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
        except RegistrationError:
            # Do not reveal whether an email already has a global account.
            return RegistrationAcceptedResponse()
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

    @application.post(
        "/v1/tenants/{tenant_id}/invitations",
        response_model=InvitationResponse,
        status_code=status.HTTP_201_CREATED,
    )
    def invite_tenant_member(
        tenant_id: UUID,
        payload: InvitationCreateRequest,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> InvitationResponse:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.members.invite" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant invitation permission required.")
        if invitation_sender is None:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Tenant invitation delivery is not configured.",
            )
        try:
            invitation = create_invitation(
                db,
                actor_user_id=user_id,
                tenant_id=tenant_id,
                email=str(payload.email),
                role_code=payload.role_code,
                expires_days=payload.expires_days,
            )
            invitation_sender(
                invitation.email,
                invitation.raw_token,
                authorization.principal.tenant_name,
            )
        except InvitationPermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant invitation permission required.") from None
        except InvitationError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from None
        except Exception:
            raise HTTPException(
                status_code=503,
                detail="Invitation could not be delivered; no invitation was confirmed.",
            ) from None
        return InvitationResponse(
            invitation_id=invitation.invitation_id,
            tenant_id=invitation.tenant_id,
            email=invitation.email,
            role_code=invitation.role_code,
            status="pending",
            expires_at=invitation.expires_at,
        )

    @application.get(
        "/v1/tenants/{tenant_id}/invitations",
        response_model=list[InvitationListItemResponse],
    )
    def tenant_invitations(
        tenant_id: UUID,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> list[InvitationListItemResponse]:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if not ({"tenant.members.read", "tenant.members.invite"} & authorization.permissions):
            raise HTTPException(status_code=403, detail="Tenant membership read permission required.")
        try:
            rows = list_invitations(db, actor_user_id=user_id, tenant_id=tenant_id)
        except InvitationPermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant membership read permission required.") from None
        return [
            InvitationListItemResponse(
                invitation_id=item.invitation_id,
                email=item.email,
                status=item.status,
                role_code=item.role_code,
                expires_at=item.expires_at,
                created_at=item.created_at,
            )
            for item in rows
        ]

    @application.post(
        "/v1/tenants/{tenant_id}/invitations/{invitation_id}/revoke",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    def revoke_tenant_invitation(
        tenant_id: UUID,
        invitation_id: UUID,
        payload: InvitationRevokeRequest,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> None:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.members.invite" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant invitation permission required.")
        try:
            revoke_invitation(
                db,
                actor_user_id=user_id,
                tenant_id=tenant_id,
                invitation_id=invitation_id,
                reason=payload.reason,
            )
        except InvitationPermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant invitation permission required.") from None
        except InvitationError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from None

    @application.post(
        "/v1/invitations/accept",
        response_model=InvitationAcceptedResponse,
    )
    def accept_tenant_invitation(
        payload: InvitationAcceptRequest,
        user_id: UUID = Depends(selection_user),
        db: Session = Depends(db_session),
    ) -> InvitationAcceptedResponse:
        try:
            accepted = accept_invitation(db, user_id=user_id, token=payload.token)
        except InvitationPermissionDenied:
            raise HTTPException(status_code=403, detail="An active verified global account is required.") from None
        except InvitationError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from None
        return InvitationAcceptedResponse(
            tenant_id=accepted.tenant_id,
            membership_id=accepted.membership_id,
        )

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

    @application.get(
        "/v1/tenants/{tenant_id}/members",
        response_model=list[TenantMemberResponse],
    )
    def tenant_members(
        tenant_id: UUID,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> list[TenantMemberResponse]:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.members.read" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant membership read permission required.")
        try:
            members = list_tenant_members(
                db, actor_user_id=user_id, tenant_id=tenant_id
            )
        except MembershipAdminPermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant membership read permission required.") from None
        return [
            TenantMemberResponse(
                membership_id=item.membership_id,
                user_id=item.user_id,
                display_name=item.display_name,
                email=item.email,
                status=item.status,
                joined_at=item.joined_at,
                roles=list(item.roles),
            )
            for item in members
        ]

    @application.patch(
        "/v1/tenants/{tenant_id}/members/{membership_id}/role",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    def update_tenant_member_role(
        tenant_id: UUID,
        membership_id: UUID,
        payload: MemberRoleRequest,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> None:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.members.manage" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant membership management permission required.")
        try:
            change_member_role(
                db,
                actor_user_id=user_id,
                tenant_id=tenant_id,
                membership_id=membership_id,
                role_code=payload.role_code,
                reason=payload.reason,
            )
        except MembershipAdminPermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant membership management permission required.") from None
        except MembershipAdminError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from None

    @application.post(
        "/v1/tenants/{tenant_id}/members/{membership_id}/{action}",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    def change_tenant_member_status(
        tenant_id: UUID,
        membership_id: UUID,
        action: str,
        payload: MemberActionRequest,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> None:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.members.manage" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant membership management permission required.")
        if action not in {"suspend", "reactivate", "remove"}:
            raise HTTPException(status_code=404, detail="Membership action was not found.")
        try:
            transition_member(
                db,
                actor_user_id=user_id,
                tenant_id=tenant_id,
                membership_id=membership_id,
                action=action,
                reason=payload.reason,
            )
        except MembershipAdminPermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant membership management permission required.") from None
        except MembershipAdminError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from None

    @application.get(
        "/v1/tenants/{tenant_id}/roles",
        response_model=list[TenantRoleResponse],
    )
    def tenant_roles(
        tenant_id: UUID,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> list[TenantRoleResponse]:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.roles.read" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant role read permission required.")
        try:
            roles = list_roles(db, actor_user_id=user_id, tenant_id=tenant_id)
        except TenantRolePermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant role read permission required.") from None
        return [
            TenantRoleResponse(
                role_id=item.role_id,
                code=item.code,
                name=item.name,
                is_system=item.is_system,
                permissions=list(item.permissions),
                member_count=item.member_count,
            )
            for item in roles
        ]

    @application.get(
        "/v1/tenants/{tenant_id}/permissions",
        response_model=list[TenantPermissionResponse],
    )
    def tenant_permission_catalog(
        tenant_id: UUID,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> list[TenantPermissionResponse]:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.roles.read" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant role read permission required.")
        try:
            permissions = list_permission_catalog(
                db, actor_user_id=user_id, tenant_id=tenant_id
            )
        except TenantRolePermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant role read permission required.") from None
        return [
            TenantPermissionResponse(
                code=item.code,
                description=item.description,
                actor_can_grant=item.actor_can_grant,
            )
            for item in permissions
        ]

    @application.post(
        "/v1/tenants/{tenant_id}/roles",
        response_model=TenantRoleResponse,
        status_code=status.HTTP_201_CREATED,
    )
    def create_tenant_role(
        tenant_id: UUID,
        payload: TenantRoleCreateRequest,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> TenantRoleResponse:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.roles.manage" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant role management permission required.")
        try:
            role_id = create_role(
                db,
                actor_user_id=user_id,
                tenant_id=tenant_id,
                code=payload.code,
                name=payload.name,
                reason=payload.reason,
            )
            roles = list_roles(db, actor_user_id=user_id, tenant_id=tenant_id)
            role = next(item for item in roles if item.role_id == role_id)
        except TenantRolePermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant role management permission required.") from None
        except (TenantRoleError, StopIteration) as exc:
            raise HTTPException(status_code=409, detail=str(exc) or "Tenant role could not be created.") from None
        return TenantRoleResponse(
            role_id=role.role_id,
            code=role.code,
            name=role.name,
            is_system=role.is_system,
            permissions=list(role.permissions),
            member_count=role.member_count,
        )

    @application.put(
        "/v1/tenants/{tenant_id}/roles/{role_id}/permissions",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    def update_tenant_role_permissions(
        tenant_id: UUID,
        role_id: UUID,
        payload: TenantRolePermissionsRequest,
        context: tuple[UUID, UUID, Any] = Depends(access_context),
        db: Session = Depends(db_session),
    ) -> None:
        user_id, current_tenant_id, authorization = context
        if tenant_id != current_tenant_id:
            raise HTTPException(status_code=404, detail="Tenant was not found.")
        if "tenant.roles.manage" not in authorization.permissions:
            raise HTTPException(status_code=403, detail="Tenant role management permission required.")
        try:
            set_role_permissions(
                db,
                actor_user_id=user_id,
                tenant_id=tenant_id,
                role_id=role_id,
                permission_codes=payload.permission_codes,
                reason=payload.reason,
            )
        except TenantRolePermissionDenied:
            raise HTTPException(status_code=403, detail="Tenant role management permission required.") from None
        except TenantRoleError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from None

    return application
