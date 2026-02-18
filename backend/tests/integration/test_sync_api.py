"""Integration tests for Sync API routes."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.sync import router


class MockSyncService:
    async def batch_sync(self, user_id, interactions):
        return {"synced": len(interactions), "failed": 0}


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.api.middleware.rate_limit import check_rate_limit
    from app.dependencies import get_sync_service
    from tests.mocks.mock_services import noop_rate_limit

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_sync_service] = lambda: MockSyncService()
    app.dependency_overrides[check_rate_limit] = noop_rate_limit

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestBatchUpload:
    def test_syncs_interactions(self, client):
        resp = client.post("/api/v1/sync/interactions", json={
            "interactions": [
                {
                    "articleId": "s1",
                    "type": "view",
                    "timestamp": "2026-02-15T10:00:00Z",
                    "timeSpent": 30.0,
                },
                {
                    "articleId": "s2",
                    "type": "done",
                    "timestamp": "2026-02-15T10:05:00Z",
                    "timeSpent": 60.0,
                },
            ]
        })
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["synced"] == 2
        assert data["failed"] == 0

    def test_empty_batch(self, client):
        resp = client.post("/api/v1/sync/interactions", json={
            "interactions": []
        })
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["synced"] == 0

    def test_invalid_interaction_type(self, client):
        resp = client.post("/api/v1/sync/interactions", json={
            "interactions": [
                {
                    "articleId": "s1",
                    "type": "invalid_type",
                    "timestamp": "2026-02-15T10:00:00Z",
                }
            ]
        })
        assert resp.status_code == 422
