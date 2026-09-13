from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_hello():
    resp = client.get("/api/hello")
    assert resp.status_code == 200
    assert resp.json() == {"msg": "hello from the flake"}
