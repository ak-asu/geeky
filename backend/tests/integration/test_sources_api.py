"""Integration tests for Sources API routes."""
from __future__ import annotations

from dataclasses import dataclass, field

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.sources import router
from app.models.common import SourceStatus, SourceType
from app.models.source import SourceDocument


class MockSourceService:
    async def add_source(self, user_id, data):
        return SourceDocument(
            id="src1",
            type=data.type,
            name=data.name,
            url=data.url,
        )

    async def list_sources(self, user_id):
        return [
            SourceDocument(id="src1", type=SourceType.RSS, name="Feed", url="https://example.com"),
        ]

    async def remove_source(self, user_id, source_id):
        pass

    async def check_health(self, user_id, source_id):
        return {
            "sourceId": source_id,
            "healthScore": 1.0,
            "status": "active",
            "lastChecked": "2026-02-15T00:00:00",
            "error": None,
        }


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.api.middleware.rate_limit import check_rate_limit
    from app.dependencies import get_source_service
    from tests.mocks.mock_services import noop_rate_limit

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_source_service] = lambda: MockSourceService()
    app.dependency_overrides[check_rate_limit] = noop_rate_limit

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestAddSource:
    def test_creates_source(self, client):
        resp = client.post("/api/v1/sources/", json={
            "type": "rss",
            "name": "My Feed",
            "url": "https://example.com/rss",
        })
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["name"] == "My Feed"
        assert data["id"] == "src1"


class TestListSources:
    def test_lists_sources(self, client):
        resp = client.get("/api/v1/sources/")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 1
        assert data[0]["name"] == "Feed"


class TestRemoveSource:
    def test_removes_source(self, client):
        resp = client.delete("/api/v1/sources/src1")
        assert resp.status_code == 200
        assert resp.json()["data"]["deleted"] is True


class TestCheckHealth:
    def test_checks_health(self, client):
        resp = client.post("/api/v1/sources/src1/check")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["healthScore"] == 1.0
        assert data["status"] == "active"
