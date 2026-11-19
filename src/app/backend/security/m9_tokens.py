"""JWTs for the canonical M9 global-login and tenant-scoped API flow."""
from __future__ import annotations

import os
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import jwt

ISSUER = "miselium-api"
SELECTION_AUDIENCE = "miselium-tenant-selection"
ACCESS_AUDIENCE = "miselium-client"


def _secret() -> str:
    secret = os.getenv("MISELIUM_JWT_SECRET", "")
    if len(secret) < 32:
        raise RuntimeError("MISELIUM_JWT_SECRET must be set to at least 32 characters")
    return secret


def create_tenant_selection_token(*, user_id: UUID, expires_minutes: int = 5) -> str:
    now = datetime.now(UTC)
    return jwt.encode(
        {
            "sub": str(user_id),
            "purpose": "tenant_selection",
            "jti": str(uuid4()),
            "iat": now,
            "exp": now + timedelta(minutes=expires_minutes),
            "iss": ISSUER,
            "aud": SELECTION_AUDIENCE,
        },
        _secret(),
        algorithm="HS256",
    )


def decode_tenant_selection_token(token: str) -> UUID:
    claims = jwt.decode(
        token,
        _secret(),
        algorithms=["HS256"],
        issuer=ISSUER,
        audience=SELECTION_AUDIENCE,
    )
    if claims.get("purpose") != "tenant_selection":
        raise jwt.InvalidTokenError("Wrong token purpose")
    return UUID(str(claims["sub"]))


def create_m9_access_token(
    *,
    user_id: UUID,
    tenant_id: UUID,
    expires_minutes: int = 30,
) -> str:
    now = datetime.now(UTC)
    return jwt.encode(
        {
            "sub": str(user_id),
            "tid": str(tenant_id),
            "purpose": "access",
            "jti": str(uuid4()),
            "iat": now,
            "exp": now + timedelta(minutes=expires_minutes),
            "iss": ISSUER,
            "aud": ACCESS_AUDIENCE,
        },
        _secret(),
        algorithm="HS256",
    )


def decode_m9_access_token(token: str) -> tuple[UUID, UUID]:
    claims = jwt.decode(
        token,
        _secret(),
        algorithms=["HS256"],
        issuer=ISSUER,
        audience=ACCESS_AUDIENCE,
    )
    if claims.get("purpose") != "access":
        raise jwt.InvalidTokenError("Wrong token purpose")
    return UUID(str(claims["sub"])), UUID(str(claims["tid"]))
