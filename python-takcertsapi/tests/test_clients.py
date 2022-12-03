"""Test the clients endpoint"""
import pytest
from fastapi.testclient import TestClient

from takcertsapi.clients.schema import ClientList


# pytest: disable=W0621


def test_list(client: TestClient, muck_cert_paths: None) -> None:
    """Test client pkg list"""
    _ = muck_cert_paths
    resp = client.get("/api/v1/clients")
    assert resp.status_code == 200
    data = ClientList(**resp.json())
    assert data.items
    for item in data.items:
        assert item.name in ("test1", "test2", "test5")


def test_get(client: TestClient, muck_cert_paths: None) -> None:
    """Test getting known pkg"""
    _ = muck_cert_paths
    resp = client.get("/api/v1/clients/test2")
    assert resp.status_code == 200


def test_post_exists(client: TestClient, temp_cert_path: None) -> None:
    """Test creating existing pkg"""
    _ = temp_cert_path
    resp = client.post("/api/v1/clients", json={"name": "test2"})
    assert resp.status_code == 409


@pytest.mark.parametrize("clientname", ["koira16", "KAHVI_2"])
def test_post(client: TestClient, temp_cert_path: None, clientname: str) -> None:
    """Test creating new pkg"""
    _ = temp_cert_path
    resp = client.post("/api/v1/clients", json={"name": clientname})
    assert resp.status_code == 200
    # Check that it's added to list too
    resp2 = client.get("/api/v1/clients")
    assert resp2.status_code == 200
    data = ClientList(**resp2.json())
    assert data.items
    found = False
    for item in data.items:
        if item.name == clientname:
            found = True
    assert found


@pytest.mark.parametrize("clientname", ["FOX-2", "1", "; rm -rf ~;", "ääkkösiä", "'; exit 1;"])
def test_post_badnames(client: TestClient, temp_cert_path: None, clientname: str) -> None:
    """Test creating new pkg"""
    _ = temp_cert_path
    resp = client.post("/api/v1/clients", json={"name": clientname})
    assert resp.status_code in (422, 403)
