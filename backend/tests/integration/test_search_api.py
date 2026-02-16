"""Integration tests for Search API routes."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.search import router
from app.models.rag import SearchResultItem


# ---- Mock search service ----


class MockHybridSearchService:
    async def search(self, user_id, query, *, top_k=20, topic=None, module_id=None):
        if not query.strip():
            return []
        results = [
            SearchResultItem(short_id="s1", title="ML Basics", snippet="Intro to ML", score=0.9, topics=["ml"]),
            SearchResultItem(short_id="s2", title="Python Tips", snippet="Python tricks", score=0.7, topics=["python"]),
        ]
        if topic:
            results = [r for r in results if topic.lower() in [t.lower() for t in r.topics]]
        return results[:top_k]


# ---- App setup ----


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.dependencies import get_hybrid_search_service

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_hybrid_search_service] = lambda: MockHybridSearchService()

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestSearchPOST:
    def test_search_returns_results(self, client):
        resp = client.post("/api/v1/search/", json={"query": "machine learning"})
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data["results"]) == 2
        assert data["total"] == 2

    def test_search_with_topic_filter(self, client):
        resp = client.post("/api/v1/search/", json={
            "query": "test",
            "filters": {"topic": "ml"},
        })
        assert resp.status_code == 200
        data = resp.json()["data"]
        for r in data["results"]:
            assert "ml" in r["topics"]

    def test_search_with_limit(self, client):
        resp = client.post("/api/v1/search/", json={"query": "test", "limit": 1})
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data["results"]) <= 1

    def test_search_result_fields(self, client):
        resp = client.post("/api/v1/search/", json={"query": "test"})
        result = resp.json()["data"]["results"][0]
        assert "shortId" in result
        assert "title" in result
        assert "snippet" in result
        assert "score" in result
        assert "topics" in result


class TestSearchGET:
    def test_get_search(self, client):
        resp = client.get("/api/v1/search/", params={"q": "python"})
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data["results"]) > 0

    def test_get_search_with_topic(self, client):
        resp = client.get("/api/v1/search/", params={"q": "test", "topic": "python"})
        assert resp.status_code == 200

    def test_get_search_missing_query(self, client):
        resp = client.get("/api/v1/search/")
        assert resp.status_code == 422  # Validation error
