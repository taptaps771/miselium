"""Small async HTTP client for the separate Miselium SaaS API."""

from __future__ import annotations

from typing import Any

import httpx


class ApiClientError(RuntimeError):
    def __init__(
        self,
        status_code: int,
        message: str,
        *,
        code: str | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code


class MiseliumApiClient:
    """API client with explicit token lifecycle and no implicit tenant header.

    The active workspace is selected by the API-issued JWT. Token persistence is deliberately
    left to a platform secure-storage adapter rather than a plaintext settings file.
    """

    def __init__(
        self,
        base_url: str,
        *,
        timeout_seconds: float = 15.0,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout_seconds
        self._transport = transport
        self._access_token: str | None = None

    @property
    def is_authenticated(self) -> bool:
        return self._access_token is not None

    def set_access_token(self, token: str | None) -> None:
        self._access_token = token or None

    async def _request(
        self,
        method: str,
        path: str,
        *,
        authenticated: bool = True,
        **kwargs: Any,
    ) -> Any:
        headers = dict(kwargs.pop("headers", {}))
        if authenticated:
            if not self._access_token:
                raise ApiClientError(401, "Sign-in is required.", code="not_authenticated")
            headers["Authorization"] = f"Bearer {self._access_token}"
        try:
            async with httpx.AsyncClient(
                base_url=self._base_url,
                timeout=self._timeout,
                transport=self._transport,
            ) as client:
                response = await client.request(method, path, headers=headers, **kwargs)
        except httpx.RequestError as exc:
            raise ApiClientError(
                503,
                "The Miselium API could not be reached.",
                code="network_error",
            ) from exc
        if response.is_error:
            try:
                detail = response.json().get("detail", "API request failed.")
            except (ValueError, AttributeError):
                detail = "API request failed."
            raise ApiClientError(
                response.status_code,
                str(detail),
                code=f"http_{response.status_code}",
            )
        if response.status_code == 204:
            return None
        return response.json()

    async def login(
        self,
        *,
        email: str,
        password: str,
        tenant_slug: str,
    ) -> dict[str, Any]:
        result = await self._request(
            "POST",
            "/v1/auth/login",
            authenticated=False,
            json={"email": email, "password": password, "tenant_slug": tenant_slug},
        )
        self.set_access_token(str(result["access_token"]))
        return result

    async def register(
        self,
        *,
        email: str,
        password: str,
        display_name: str,
        tenant_name: str,
        tenant_slug: str,
    ) -> dict[str, Any]:
        result = await self._request(
            "POST",
            "/v1/auth/register",
            authenticated=False,
            json={
                "email": email,
                "password": password,
                "display_name": display_name,
                "tenant_name": tenant_name,
                "tenant_slug": tenant_slug,
            },
        )
        self.set_access_token(str(result["access_token"]))
        return result

    async def me(self) -> dict[str, Any]:
        return await self._request("GET", "/v1/me")

    async def list_tenants(self) -> list[dict[str, str]]:
        return await self._request("GET", "/v1/tenants")

    async def list_records(self) -> list[dict[str, Any]]:
        return await self._request("GET", "/v1/records")

    async def create_record(
        self,
        *,
        title: str,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        return await self._request(
            "POST",
            "/v1/records",
            json={"title": title, "payload": payload or {}},
        )

    def logout(self) -> None:
        self._access_token = None
