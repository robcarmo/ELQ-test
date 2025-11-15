from fastapi.testclient import TestClient
import os

from app import app

client = TestClient(app)


def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "healthy"
    assert "version" in body


def test_hello_endpoint_default_env():
    response = client.get("/api/hello")
    assert response.status_code == 200
    body = response.json()
    assert body["message"] == "Hello from Eloquent AI!"
    # default env if not set
    assert "environment" in body


def test_hello_endpoint_with_custom_env(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test-env")
    response = client.get("/api/hello")
    assert response.status_code == 200
    body = response.json()
    assert body["environment"] == "test-env"