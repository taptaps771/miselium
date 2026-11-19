"""JWT access token creation and verification."""

from __future__ import annotations

import os
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import jwt


ALGORITHM = "HS256"


def _secret() -> str:
    value = os.getenv("MISELIUM_JWT_SECRET", "")
    if len(value) < 32:
        raise RuntimeError("MISELIUM_JWT_SECRET must be set to at least 32 characters")
    return value


def create_access_token(
    *,
    user_id: str,
    tenant_id: str,
    role: str,
    expires_minutes: int = 30,
) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": user_id,
        "tid": tenant_id,
        "role": role,
        "jti": str(uuid4()),
        "iat": now,
        "exp": now + timedelta(minutes=expires_minutes),
        "iss": "miselium-api",
        "aud": "miselium-client",
    }
    return jwt.encode(payload, _secret(), algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict[str, object]:
    return jwt.decode(
        token,
        _secret(),
        algorithms=[ALGORITHM],
        issuer="miselium-api",
        audience="miselium-client",
    )
