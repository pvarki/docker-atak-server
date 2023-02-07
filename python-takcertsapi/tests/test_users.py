"""Tests for users api endpoints"""
import pytest
from fastapi.testclient import TestClient

from takcertsapi.users.schema import UserList


# pytest: disable=W0621


def test_list_users(client: TestClient, muck_cert_paths: None) -> None:
    """Test user cert list"""
    _ = muck_cert_paths
    resp = client.get("/api/v1/users")
    assert resp.status_code == 200
    data = UserList(**resp.json())
    assert data.items
    for item in data.items:
        assert item.username in ("admin", "someone")


def test_get_user(client: TestClient, muck_cert_paths: None) -> None:
    """Test getting known cert"""
    _ = muck_cert_paths
    resp = client.get("/api/v1/users/someone")
    assert resp.status_code == 200


@pytest.mark.xfail(reason="cannot work before larger redesign")
def test_post_user_exists(client: TestClient, temp_cert_path: None) -> None:
    """Test creating existing user"""
    _ = temp_cert_path
    resp = client.post(
        "/api/v1/users", json={"username": "admin", "passphrase": "a_valid_passphrase"}  # pragma: allowlist secret
    )
    assert resp.status_code == 409


@pytest.mark.xfail(reason="cannot work before larger redesign")
@pytest.mark.parametrize("username", ["hundi12", "COFE_3"])
def test_post_user(client: TestClient, temp_cert_path: None, username: str) -> None:
    """Test creating new users with valid names"""
    _ = temp_cert_path
    resp = client.post(
        "/api/v1/users", json={"username": username, "passphrase": "a_valid_passphrase"}  # pragma: allowlist secret
    )
    assert resp.status_code == 200
    # Check that it's added to list too
    resp2 = client.get("/api/v1/users")
    assert resp2.status_code == 200
    data = UserList(**resp2.json())
    assert data.items
    found = False
    for item in data.items:
        if item.username == username:
            found = True
    assert found


@pytest.mark.xfail(reason="cannot work before larger redesign")
@pytest.mark.parametrize("username", ["DOG-2", "1", "; rm -rf ~;", "ääkkösiä", "'; exit 1;"])
def test_post_user_badnames(client: TestClient, temp_cert_path: None, username: str) -> None:
    """Test creating new users with invalid names"""
    _ = temp_cert_path
    resp = client.post(
        "/api/v1/users", json={"username": username, "passphrase": "a_valid_passphrase"}  # pragma: allowlist secret
    )
    assert resp.status_code in (422, 403)
