"""Integration tests for Bookmarks API routes."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.bookmarks import router


class MockBookmarkService:
    async def create_bookmark(self, user_id, short_id):
        return {"id": "b1", "shortId": short_id, "alreadyBookmarked": False}

    async def remove_bookmark(self, user_id, short_id):
        return True

    async def list_bookmarks(self, user_id, limit=50, cursor=None):
        items = [
            {
                "id": "b1",
                "shortId": "s1",
                "createdAt": "2026-02-15T00:00:00",
                "short": {"title": "Test", "summary": "Sum", "topics": ["ml"], "difficulty": 0.5},
            }
        ]
        return items, None


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.api.middleware.rate_limit import check_rate_limit
    from app.dependencies import get_bookmark_service
    from tests.mocks.mock_services import noop_rate_limit

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_bookmark_service] = lambda: MockBookmarkService()
    app.dependency_overrides[check_rate_limit] = noop_rate_limit

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestCreateBookmark:
    def test_creates_bookmark(self, client):
        resp = client.post("/api/v1/bookmarks/s1")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["shortId"] == "s1"
        assert data["alreadyBookmarked"] is False


class TestRemoveBookmark:
    def test_removes_bookmark(self, client):
        resp = client.delete("/api/v1/bookmarks/s1")
        assert resp.status_code == 200
        assert resp.json()["data"]["removed"] is True


class TestListBookmarks:
    def test_lists_bookmarks(self, client):
        resp = client.get("/api/v1/bookmarks/")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 1
        assert data[0]["short"]["title"] == "Test"

    def test_pagination_params(self, client):
        resp = client.get("/api/v1/bookmarks/?limit=10")
        assert resp.status_code == 200
        meta = resp.json()["meta"]
        assert meta["hasMore"] is False
