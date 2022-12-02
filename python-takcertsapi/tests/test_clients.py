"""Test the clients endpoint"""
from fastapi.testclient import TestClient

from takcertsapi.clients.schema import ListClients


# pytest: disable=W0621


def test_list(client: TestClient) -> None:
    """Test client pkg list"""
    resp = client.get("/api/v1/clients")
    assert resp.status_code == 200
    data = ListClients(**resp.json())
    assert data.items
    for item in data.items:
        assert item.name in ("test1", "test2", "test5")


def test_get(client: TestClient) -> None:
    """Test getting known pkg"""
    resp = client.get("/api/v1/clients/test2")
    assert resp.status_code == 200
