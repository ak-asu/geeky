"""Integration tests for Analytics API routes."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.analytics import router
from app.models.analytics import (
    Achievement,
    DashboardResponse,
    MasteryDistribution,
    StreakResponse,
    StudyActivity,
    TopicProgress,
)


# ---- Mock analytics aggregator ----


class MockAnalyticsAggregator:
    async def get_dashboard(self, user_id):
        return DashboardResponse(
            streak=StreakResponse(current=5, longest=10, last_active_date="2026-02-15"),
            topics_progress=[
                TopicProgress(topic="ml", shorts_completed=3, total_shorts=5, mastery=0.6),
                TopicProgress(topic="python", shorts_completed=2, total_shorts=3, mastery=0.7),
            ],
            mastery=MasteryDistribution(new=2, learning=3, review=5, relearning=1, total=11),
            recent_activity=[
                StudyActivity(date="2026-02-15", reviews=10, time_spent_minutes=25.0),
            ],
            total_notes=5,
            total_shorts=8,
            total_concepts=15,
            total_shorts_completed=5,
            total_time_spent_minutes=120.0,
            achievements=[
                Achievement(id="first_note", name="First Note", description="Created first note", unlocked=True),
            ],
        )

    async def get_streak(self, user_id):
        return StreakResponse(current=5, longest=10, last_active_date="2026-02-15")

    async def get_mastery_distribution(self, user_id):
        return MasteryDistribution(new=2, learning=3, review=5, relearning=1, total=11)


# ---- App setup ----


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.dependencies import get_analytics_aggregator

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_analytics_aggregator] = lambda: MockAnalyticsAggregator()

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestDashboard:
    def test_get_dashboard(self, client):
        resp = client.get("/api/v1/analytics/dashboard")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["totalNotes"] == 5
        assert data["totalShorts"] == 8
        assert data["totalConcepts"] == 15

    def test_dashboard_has_streak(self, client):
        data = client.get("/api/v1/analytics/dashboard").json()["data"]
        assert data["streak"]["current"] == 5
        assert data["streak"]["longest"] == 10

    def test_dashboard_has_mastery(self, client):
        data = client.get("/api/v1/analytics/dashboard").json()["data"]
        assert data["mastery"]["total"] == 11
        assert data["mastery"]["review"] == 5

    def test_dashboard_has_topics(self, client):
        data = client.get("/api/v1/analytics/dashboard").json()["data"]
        assert len(data["topicsProgress"]) == 2

    def test_dashboard_has_achievements(self, client):
        data = client.get("/api/v1/analytics/dashboard").json()["data"]
        assert len(data["achievements"]) > 0
        assert data["achievements"][0]["unlocked"] is True


class TestStreak:
    def test_get_streak(self, client):
        resp = client.get("/api/v1/analytics/streak")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["current"] == 5
        assert data["longest"] == 10


class TestMastery:
    def test_get_mastery(self, client):
        resp = client.get("/api/v1/analytics/mastery")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["new"] == 2
        assert data["learning"] == 3
        assert data["review"] == 5
        assert data["total"] == 11


class TestAchievements:
    def test_get_achievements(self, client):
        resp = client.get("/api/v1/analytics/achievements")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data["achievements"]) > 0
