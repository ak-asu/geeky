"""Integration tests for Recommendations API routes."""
from __future__ import annotations

from dataclasses import dataclass

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.recommendations import router
from app.services.recommendation.base import ScoredShort


class MockFeedRanker:
    async def get_ranked_feed(self, user_id, limit=20):
        return [
            ScoredShort(
                short_id="s1",
                score=0.85,
                relevance_score=0.9,
                capability_score=0.8,
                novelty_score=0.85,
            ),
            ScoredShort(
                short_id="s2",
                score=0.72,
                relevance_score=0.7,
                capability_score=0.75,
                novelty_score=0.7,
            ),
        ][:limit]

    async def refresh(self, user_id):
        return {"userId": user_id, "totalScored": 10, "topScore": 0.85}


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.dependencies import get_feed_ranker

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_feed_ranker] = lambda: MockFeedRanker()

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestGetRankedFeed:
    def test_returns_ranked_feed(self, client):
        resp = client.get("/api/v1/recommendations/")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 2
        assert data[0]["shortId"] == "s1"
        assert data[0]["score"] == 0.85

    def test_limit_param(self, client):
        resp = client.get("/api/v1/recommendations/?limit=1")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 1

    def test_feed_has_score_breakdown(self, client):
        data = client.get("/api/v1/recommendations/").json()["data"]
        assert "relevanceScore" in data[0]
        assert "capabilityScore" in data[0]
        assert "noveltyScore" in data[0]


class TestForceRecalculation:
    def test_refreshes_recommendations(self, client):
        resp = client.post("/api/v1/recommendations/refresh")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["totalScored"] == 10
        assert data["topScore"] == 0.85
