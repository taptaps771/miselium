"""Validated API request and response schemas."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12, max_length=256)
    display_name: str = Field(min_length=1, max_length=120)
    tenant_name: str = Field(min_length=2, max_length=160)
    tenant_slug: str = Field(pattern=r"^[a-z0-9](?:[a-z0-9-]{1,78}[a-z0-9])$")


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    tenant_slug: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 1800
    tenant_id: str
    role: str


class RecordCreate(BaseModel):
    title: str = Field(min_length=1, max_length=180)
    payload: dict[str, object] = Field(default_factory=dict)


class RecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    tenant_id: str
    title: str
    payload: dict[str, object]


class DeviceRegistrationRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=160)
    platform: str = Field(pattern=r"^(android|windows|linux|macos)$")
    push_token: str = Field(min_length=10, max_length=8192)


class InvitationCreate(BaseModel):
    email: EmailStr
    role: str = Field(default="member", pattern=r"^(member|admin)$")


class InvitationAccept(BaseModel):
    invitation_token: str = Field(min_length=32, max_length=128)
