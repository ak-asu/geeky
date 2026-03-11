"""Integration tests for Shorts API — subscription enforcement."""

from __future__ import annotations

import pytest
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

from app.api.v1.shorts import router
from app.exceptions import NotFoundError, PremiumRequiredError
from app.models.short import ShortDocument

_TEST_USER = "test-user-shorts"


class MockShortRepository:
    """In-memory short repository for integration tests."""

    def __init__(self, shorts: list[ShortDocument] | None = None):
        self._shorts: dict[str, ShortDocument] = {}
        for s in shorts or []:
            self._shorts[s.id or "mock-id"] = s

    async def list(self, user_id, limit=50, cursor=None):
        items = list(self._shorts.values())[:limit]
        return items, None

    async def get(self, user_id, short_id):
        return self._shorts.get(short_id)

    async def get_by_topic(self, user_id, topic, limit=50):
        return [s for s in self._shorts.values() if topic in (s.topics or [])][:limit]

    async def query(self, user_id, filters=None, limit=50):
        return list(self._shorts.values())[:limit]


class _FreeSubscriptionService:
    """Subscription service that always raises PremiumRequiredError — simulates free tier."""

    async def check_processing_quota(self, user_id: str) -> None:
        raise PremiumRequiredError(
            "AI note processing and Shorts require a Premium subscription."
        )


class _PremiumSubscriptionService:
    """Subscription service that always passes — simulates premium tier."""

    async def check_processing_quota(self, user_id: str) -> None:
        return None


def _make_test_app(short_repo: MockShortRepository, subscription_svc) -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.dependencies import get_short_repository, get_subscription_service

    app = FastAPI()

    @app.exception_handler(NotFoundError)
    async def not_found_handler(_request: Request, exc: NotFoundError) -> JSONResponse:
        return JSONResponse(
            status_code=404,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    @app.exception_handler(PremiumRequiredError)
    async def premium_handler(_request: Request, exc: PremiumRequiredError) -> JSONResponse:
        return JSONResponse(
            status_code=402,
            content={"error": {"code": "premium_required", "message": str(exc)}},
        )

    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: _TEST_USER
    app.dependency_overrides[get_short_repository] = lambda: short_repo
    app.dependency_overrides[get_subscription_service] = lambda: subscription_svc

    return app


@pytest.fixture
def premium_client():
    return TestClient(_make_test_app(MockShortRepository(), _PremiumSubscriptionService()))


@pytest.fixture
def free_client():
    return TestClient(_make_test_app(MockShortRepository(), _FreeSubscriptionService()))


class TestListShortsPremiumGate:
    def test_premium_user_can_list_shorts(self, premium_client):
        response = premium_client.get("/api/v1/shorts")
        assert response.status_code == 200
        assert "data" in response.json()

    def test_free_user_blocked_from_list_shorts(self, free_client):
        response = free_client.get("/api/v1/shorts")
        assert response.status_code == 402
        assert "premium_required" in response.json()["error"]["code"]

    def test_free_user_blocked_with_topic_filter(self, free_client):
        response = free_client.get("/api/v1/shorts?topic=python")
        assert response.status_code == 402

    def test_free_user_blocked_with_difficulty_filter(self, free_client):
        response = free_client.get("/api/v1/shorts?min_difficulty=0.2&max_difficulty=0.8")
        assert response.status_code == 402


class TestGetShortPremiumGate:
    def test_premium_user_gets_404_for_missing_short(self, premium_client):
        response = premium_client.get("/api/v1/shorts/nonexistent-id")
        assert response.status_code == 404

    def test_free_user_blocked_before_repo_lookup(self, free_client):
        # Must return 402 even for existing short IDs — check fires before DB lookup
        response = free_client.get("/api/v1/shorts/any-id")
        assert response.status_code == 402
