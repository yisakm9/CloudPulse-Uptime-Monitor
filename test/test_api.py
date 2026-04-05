# ──────────────────────────────────────────────────────────────
# CloudPulse — Unit Tests
# ──────────────────────────────────────────────────────────────
# Tests the health check endpoint, CRUD API, and uptime
# calculation logic using an in-memory SQLite database.
# ──────────────────────────────────────────────────────────────

import uuid
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Patch settings BEFORE importing app modules
with patch.dict("os.environ", {
    "DB_HOST": "localhost",
    "DB_NAME": "test",
    "DB_USER": "test",
    "DB_PASSWORD": "test",
    "DB_PORT": "5432",
    "APP_ENV": "test",
}):
    from main import app
    from database import Base, get_db
    from models import Endpoint, HealthCheck

# ─── Test Database Setup ─────────────────────────────────────

TEST_DATABASE_URL = "sqlite://"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db():
    """Create tables before each test, drop after."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


# ──────────────────────────────────────────────────────────────
# Health Check Tests
# ──────────────────────────────────────────────────────────────

class TestHealthCheck:
    def test_health_endpoint_returns_200(self):
        response = client.get("/api/health")
        assert response.status_code == 200

    def test_health_response_contains_status(self):
        response = client.get("/api/health")
        data = response.json()
        assert "status" in data
        assert data["service"] == "cloudpulse-web"


# ──────────────────────────────────────────────────────────────
# Endpoint CRUD Tests
# ──────────────────────────────────────────────────────────────

class TestEndpointCRUD:
    def test_create_endpoint(self):
        response = client.post("/api/endpoints/", json={
            "name": "Google",
            "url": "https://www.google.com",
            "check_interval": 300,
        })
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Google"
        assert data["url"] == "https://www.google.com"
        assert data["check_interval"] == 300
        assert data["is_active"] is True
        assert "id" in data

    def test_create_endpoint_with_defaults(self):
        response = client.post("/api/endpoints/", json={
            "name": "Test Site",
            "url": "https://example.com",
        })
        assert response.status_code == 201
        data = response.json()
        assert data["check_interval"] == 300  # default
        assert data["is_active"] is True  # default

    def test_list_endpoints_empty(self):
        response = client.get("/api/endpoints/")
        assert response.status_code == 200
        assert response.json() == []

    def test_list_endpoints_with_data(self):
        # Create two endpoints
        client.post("/api/endpoints/", json={"name": "A", "url": "https://a.com"})
        client.post("/api/endpoints/", json={"name": "B", "url": "https://b.com"})

        response = client.get("/api/endpoints/")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2

    def test_get_endpoint_by_id(self):
        create_resp = client.post("/api/endpoints/", json={
            "name": "GitHub",
            "url": "https://github.com",
        })
        endpoint_id = create_resp.json()["id"]

        response = client.get(f"/api/endpoints/{endpoint_id}")
        assert response.status_code == 200
        assert response.json()["name"] == "GitHub"

    def test_get_endpoint_not_found(self):
        fake_id = str(uuid.uuid4())
        response = client.get(f"/api/endpoints/{fake_id}")
        assert response.status_code == 404

    def test_update_endpoint(self):
        create_resp = client.post("/api/endpoints/", json={
            "name": "Old Name",
            "url": "https://old.com",
        })
        endpoint_id = create_resp.json()["id"]

        response = client.put(f"/api/endpoints/{endpoint_id}", json={
            "name": "New Name",
            "url": "https://new.com",
            "check_interval": 60,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "New Name"
        assert data["url"] == "https://new.com"
        assert data["check_interval"] == 60

    def test_update_partial(self):
        create_resp = client.post("/api/endpoints/", json={
            "name": "Partial",
            "url": "https://partial.com",
        })
        endpoint_id = create_resp.json()["id"]

        response = client.put(f"/api/endpoints/{endpoint_id}", json={
            "is_active": False,
        })
        assert response.status_code == 200
        assert response.json()["is_active"] is False
        assert response.json()["name"] == "Partial"  # unchanged

    def test_delete_endpoint(self):
        create_resp = client.post("/api/endpoints/", json={
            "name": "ToDelete",
            "url": "https://delete.me",
        })
        endpoint_id = create_resp.json()["id"]

        response = client.delete(f"/api/endpoints/{endpoint_id}")
        assert response.status_code == 204

        # Verify it's gone
        get_resp = client.get(f"/api/endpoints/{endpoint_id}")
        assert get_resp.status_code == 404

    def test_delete_not_found(self):
        fake_id = str(uuid.uuid4())
        response = client.delete(f"/api/endpoints/{fake_id}")
        assert response.status_code == 404


# ──────────────────────────────────────────────────────────────
# Endpoint History Tests
# ──────────────────────────────────────────────────────────────

class TestEndpointHistory:
    def test_get_history_empty(self):
        create_resp = client.post("/api/endpoints/", json={
            "name": "NoHistory",
            "url": "https://nohistory.com",
        })
        endpoint_id = create_resp.json()["id"]

        response = client.get(f"/api/endpoints/{endpoint_id}/history")
        assert response.status_code == 200
        assert response.json() == []

    def test_get_history_with_checks(self):
        # Create endpoint
        create_resp = client.post("/api/endpoints/", json={
            "name": "WithHistory",
            "url": "https://withhistory.com",
        })
        endpoint_id = create_resp.json()["id"]

        # Insert health checks directly into DB
        db = TestingSessionLocal()
        for i in range(5):
            check = HealthCheck(
                endpoint_id=uuid.UUID(endpoint_id),
                status_code=200,
                response_time_ms=100 + i * 10,
                is_healthy=True,
                checked_at=datetime.now(timezone.utc) - timedelta(minutes=i * 5),
            )
            db.add(check)
        db.commit()
        db.close()

        response = client.get(f"/api/endpoints/{endpoint_id}/history")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 5
        assert all(c["is_healthy"] for c in data)

    def test_history_not_found(self):
        fake_id = str(uuid.uuid4())
        response = client.get(f"/api/endpoints/{fake_id}/history")
        assert response.status_code == 404


# ──────────────────────────────────────────────────────────────
# Uptime Calculation Tests
# ──────────────────────────────────────────────────────────────

class TestUptimeCalculation:
    def test_uptime_100_percent(self):
        create_resp = client.post("/api/endpoints/", json={
            "name": "AllUp",
            "url": "https://allup.com",
        })
        endpoint_id = create_resp.json()["id"]

        db = TestingSessionLocal()
        for i in range(10):
            check = HealthCheck(
                endpoint_id=uuid.UUID(endpoint_id),
                status_code=200,
                response_time_ms=50,
                is_healthy=True,
                checked_at=datetime.now(timezone.utc) - timedelta(minutes=i * 5),
            )
            db.add(check)
        db.commit()
        db.close()

        response = client.get(f"/api/endpoints/{endpoint_id}")
        assert response.status_code == 200
        assert response.json()["uptime_24h"] == 100.0

    def test_uptime_with_failures(self):
        create_resp = client.post("/api/endpoints/", json={
            "name": "SomeFail",
            "url": "https://somefail.com",
        })
        endpoint_id = create_resp.json()["id"]

        db = TestingSessionLocal()
        # 8 healthy + 2 unhealthy = 80% uptime
        for i in range(8):
            db.add(HealthCheck(
                endpoint_id=uuid.UUID(endpoint_id),
                status_code=200,
                response_time_ms=50,
                is_healthy=True,
                checked_at=datetime.now(timezone.utc) - timedelta(minutes=i * 5),
            ))
        for i in range(2):
            db.add(HealthCheck(
                endpoint_id=uuid.UUID(endpoint_id),
                status_code=500,
                response_time_ms=0,
                is_healthy=False,
                error_message="Internal Server Error",
                checked_at=datetime.now(timezone.utc) - timedelta(minutes=(8 + i) * 5),
            ))
        db.commit()
        db.close()

        response = client.get(f"/api/endpoints/{endpoint_id}")
        assert response.status_code == 200
        assert response.json()["uptime_24h"] == 80.0

    def test_uptime_no_checks_returns_100(self):
        create_resp = client.post("/api/endpoints/", json={
            "name": "NoChecks",
            "url": "https://nochecks.com",
        })
        endpoint_id = create_resp.json()["id"]

        response = client.get(f"/api/endpoints/{endpoint_id}")
        assert response.status_code == 200
        assert response.json()["uptime_24h"] == 100.0
