from datetime import datetime

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_matches_contract() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["providers"] == []
    assert datetime.fromisoformat(body["timestamp"].replace("Z", "+00:00")).tzinfo


def test_openapi_docs_are_available() -> None:
    response = client.get("/docs")

    assert response.status_code == 200
