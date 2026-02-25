"""Integration tests for User Profile API routes."""
from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.middleware.auth import TokenClaims
from app.api.v1.users import router
from app.exceptions import UserNotFoundError
from app.models.user import UserDocument, UserProfileUpdate


# ---- Mock profile service ----


class MockProfileService:
    def __init__(self):
        self._user = UserDocument(
            id="test-user-001",
            name="Test User",
            email="test@example.com",
            interests=["ml", "python"],
        )

    async def get_profile(self, user_id):
        if user_id != "test-user-001":
            raise UserNotFoundError(user_id)
        return self._user

    async def get_or_create_profile(self, user_id, *, name="", email="", avatar_url=""):
        if user_id != "test-user-001":
            raise UserNotFoundError(user_id)
        return self._user

    async def update_profile(self, user_id, update: UserProfileUpdate, *, name="", email="", avatar_url=""):
        if user_id != "test-user-001":
            raise UserNotFoundError(user_id)
        if update.name:
            self._user.name = update.name
        return self._user

    async def get_stats(self, user_id):
        return {
            "totalNotes": 10,
            "totalShorts": 25,
            "totalConcepts": 15,
            "totalReviewStates": 20,
            "streak": {"current": 5, "longest": 12},
        }

    async def export_data(self, user_id):
        return {
            "profile": {"id": user_id, "name": "Test User"},
            "notes": [],
            "shorts": [],
            "exportedAt": "2026-02-16T00:00:00Z",
        }

    async def delete_account(self, user_id):
        if user_id != "test-user-001":
            raise UserNotFoundError(user_id)


# ---- App setup ----

_TEST_CLAIMS = TokenClaims(
    uid="test-user-001",
    name="Test User",
    email="test@example.com",
    avatar_url="",
)


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_claims, verify_firebase_token
    from app.dependencies import get_profile_service

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    # Register exception handler for NotFoundError
    from app.exceptions import NotFoundError
    from fastapi.responses import JSONResponse

    @app.exception_handler(NotFoundError)
    async def not_found_handler(_request, exc):
        return JSONResponse(status_code=404, content={"error": {"code": exc.code, "message": exc.message}})

    # GET/PATCH /me use CurrentUserClaims; stats/export/delete use CurrentUserId
    app.dependency_overrides[verify_firebase_claims] = lambda: _TEST_CLAIMS
    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_profile_service] = lambda: MockProfileService()

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestGetProfile:
    def test_get_current_user(self, client):
        resp = client.get("/api/v1/users/me")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["name"] == "Test User"
        assert data["email"] == "test@example.com"

    def test_profile_has_interests(self, client):
        data = client.get("/api/v1/users/me").json()["data"]
        assert "interests" in data
        assert len(data["interests"]) == 2


class TestUpdateProfile:
    def test_update_name(self, client):
        resp = client.patch("/api/v1/users/me", json={"name": "Updated Name"})
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["name"] == "Updated Name"

    def test_partial_update(self, client):
        resp = client.patch("/api/v1/users/me", json={"interests": ["ml", "data science"]})
        assert resp.status_code == 200


class TestGetStats:
    def test_get_stats(self, client):
        resp = client.get("/api/v1/users/me/stats")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["totalNotes"] == 10
        assert data["totalShorts"] == 25
        assert data["streak"]["current"] == 5


class TestExportData:
    def test_export(self, client):
        resp = client.post("/api/v1/users/me/export")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert "profile" in data
        assert "notes" in data
        assert "exportedAt" in data


class TestDeleteAccount:
    def test_delete(self, client):
        resp = client.delete("/api/v1/users/me")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["message"] == "Account deleted successfully"
