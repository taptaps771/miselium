from __future__ import annotations

from fastapi.testclient import TestClient

from app.backend.main import create_app


def _register(client: TestClient, *, email: str, slug: str) -> str:
    response = client.post("/v1/auth/register", json={
        "email": email,
        "password": "a-long-test-password-123",
        "display_name": email.split("@")[0],
        "tenant_name": f"Workspace {slug}",
        "tenant_slug": slug,
    })
    assert response.status_code == 201, response.text
    return response.json()["access_token"]


def test_tenant_records_are_isolated_and_cross_tenant_reads_are_hidden(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("MISELIUM_JWT_SECRET", "test-secret-that-is-long-enough-for-hmac")
    app = create_app(database_url=f"sqlite:///{tmp_path / 'test.db'}", create_schema=True)
    with TestClient(app) as client:
        token_a = _register(client, email="a@example.com", slug="tenant-a")
        token_b = _register(client, email="b@example.com", slug="tenant-b")
        created = client.post("/v1/records", headers={"Authorization": f"Bearer {token_a}"}, json={"title": "A private record"})
        assert created.status_code == 201
        record_id = created.json()["id"]

        own_records = client.get("/v1/records", headers={"Authorization": f"Bearer {token_a}"})
        other_records = client.get("/v1/records", headers={"Authorization": f"Bearer {token_b}"})
        cross_read = client.get(f"/v1/records/{record_id}", headers={"Authorization": f"Bearer {token_b}"})

        assert len(own_records.json()) == 1
        assert other_records.json() == []
        assert cross_read.status_code == 404


def test_membership_is_required_even_for_a_valid_user_token(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("MISELIUM_JWT_SECRET", "test-secret-that-is-long-enough-for-hmac")
    app = create_app(database_url=f"sqlite:///{tmp_path / 'membership.db'}", create_schema=True)
    with TestClient(app) as client:
        token = _register(client, email="member@example.com", slug="member-space")
        assert client.get("/v1/me", headers={"Authorization": f"Bearer {token}"}).status_code == 200
        assert client.get("/v1/me").status_code == 401


def test_login_requires_a_matching_tenant_membership(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("MISELIUM_JWT_SECRET", "test-secret-that-is-long-enough-for-hmac")
    app = create_app(database_url=f"sqlite:///{tmp_path / 'login.db'}", create_schema=True)
    with TestClient(app) as client:
        _register(client, email="owner@example.com", slug="owner-space")
        response = client.post("/v1/auth/login", json={
            "email": "owner@example.com", "password": "a-long-test-password-123", "tenant_slug": "missing-space"
        })
        assert response.status_code == 401


def test_invitation_lets_a_user_join_another_tenant_without_sharing_data(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("MISELIUM_JWT_SECRET", "test-secret-that-is-long-enough-for-hmac")
    monkeypatch.setenv("MISELIUM_ENVIRONMENT", "development")
    app = create_app(database_url=f"sqlite:///{tmp_path / 'invite.db'}", create_schema=True)
    with TestClient(app) as client:
        owner_token = _register(client, email="workspace-owner@example.com", slug="team-one")
        member_token = _register(client, email="invited-user@example.com", slug="team-two")
        invited = client.post("/v1/invitations", headers={"Authorization": f"Bearer {owner_token}"}, json={
            "email": "invited-user@example.com", "role": "member"
        })
        assert invited.status_code == 201
        invite_token = invited.json()["development_token"]
        accepted = client.post("/v1/invitations/accept", headers={"Authorization": f"Bearer {member_token}"}, json={
            "invitation_token": invite_token
        })
        assert accepted.status_code == 200
        workspaces = client.get("/v1/tenants", headers={"Authorization": f"Bearer {member_token}"})
        assert {item["slug"] for item in workspaces.json()} == {"team-one", "team-two"}


def test_invitation_cannot_be_accepted_by_another_email(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("MISELIUM_JWT_SECRET", "test-secret-that-is-long-enough-for-hmac")
    monkeypatch.setenv("MISELIUM_ENVIRONMENT", "development")
    app = create_app(database_url=f"sqlite:///{tmp_path / 'wrong-invite.db'}", create_schema=True)
    with TestClient(app) as client:
        owner_token = _register(client, email="owner2@example.com", slug="secure-space")
        stranger_token = _register(client, email="stranger@example.com", slug="stranger-space")
        invited = client.post("/v1/invitations", headers={"Authorization": f"Bearer {owner_token}"}, json={"email": "somebody@example.com"})
        # A workspace owner cannot silently invite an identity different from the current account.
        assert invited.status_code == 201
        response = client.post("/v1/invitations/accept", headers={"Authorization": f"Bearer {stranger_token}"}, json={"invitation_token": invited.json()["development_token"]})
        assert response.status_code == 403


def test_device_registration_is_scoped_and_updates_existing_device(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("MISELIUM_JWT_SECRET", "test-secret-that-is-long-enough-for-hmac")
    app = create_app(database_url=f"sqlite:///{tmp_path / 'devices.db'}", create_schema=True)
    with TestClient(app) as client:
        token = _register(client, email="device@example.com", slug="device-space")
        headers = {"Authorization": f"Bearer {token}"}
        first = client.post("/v1/devices", headers=headers, json={
            "device_id": "android-01", "platform": "android", "push_token": "fcm-token-123456789"
        })
        second = client.post("/v1/devices", headers=headers, json={
            "device_id": "android-01", "platform": "android", "push_token": "fcm-token-updated-123456"
        })
        assert first.status_code == 201
        assert second.status_code == 201
        assert second.json()["status"] == "registered"
