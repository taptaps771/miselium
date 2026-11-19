from __future__ import annotations

import httpx
import pytest

from app.application.api_client import ApiClientError, MiseliumApiClient


@pytest.mark.asyncio
async def test_client_requires_authentication_for_private_endpoints() -> None:
    client = MiseliumApiClient("https://api.example.test")
    with pytest.raises(ApiClientError) as error:
        await client.me()
    assert error.value.status_code == 401


@pytest.mark.asyncio
async def test_client_login_sets_bearer_token_and_can_logout() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        if request.url.path == "/v1/auth/login":
            return httpx.Response(200, json={"access_token": "test-token", "tenant_id": "t1", "role": "owner"})
        return httpx.Response(200, json={"tenant": {"id": "t1"}})

    client = MiseliumApiClient("https://api.example.test", transport=httpx.MockTransport(handler))
    await client.login(email="a@example.com", password="secret", tenant_slug="workspace")
    assert client.is_authenticated
    await client.me()
    assert seen[-1].headers["Authorization"] == "Bearer test-token"
    client.logout()
    assert not client.is_authenticated


@pytest.mark.asyncio
async def test_client_maps_api_error_without_leaking_response_object() -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(403, json={"detail": "Workspace administrator role required."})

    client = MiseliumApiClient("https://api.example.test", transport=httpx.MockTransport(handler))
    client.set_access_token("token")
    with pytest.raises(ApiClientError, match="administrator") as error:
        await client.list_tenants()
    assert error.value.status_code == 403
    assert error.value.code == "http_403"


@pytest.mark.asyncio
async def test_client_maps_network_failure_to_stable_error() -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("offline")

    client = MiseliumApiClient("https://api.example.test", transport=httpx.MockTransport(handler))
    client.set_access_token("token")
    with pytest.raises(ApiClientError) as error:
        await client.me()
    assert error.value.status_code == 503
    assert error.value.code == "network_error"
