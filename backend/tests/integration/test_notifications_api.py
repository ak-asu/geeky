"""Integration tests for Notifications API routes."""
from __future__ import annotations

from dataclasses import dataclass, field

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.notifications import router
from app.models.common import NotificationType
from app.models.notification import NotificationDocument


class MockNotificationService:
    async def list_notifications(self, user_id, limit=50, cursor=None):
        return [
            NotificationDocument(
                id="n1",
                title="Review Time",
                body="You have 5 cards due",
                type=NotificationType.REVIEW,
            ),
        ], None

    async def mark_read(self, user_id, notification_id):
        pass

    async def mark_all_read(self, user_id):
        return 3


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.dependencies import get_notification_service

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_notification_service] = lambda: MockNotificationService()

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestListNotifications:
    def test_lists_notifications(self, client):
        resp = client.get("/api/v1/notifications/")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 1
        assert data[0]["title"] == "Review Time"

    def test_pagination_meta(self, client):
        resp = client.get("/api/v1/notifications/?limit=10")
        assert resp.status_code == 200
        meta = resp.json()["meta"]
        assert meta["hasMore"] is False


class TestMarkRead:
    def test_marks_notification_read(self, client):
        resp = client.post("/api/v1/notifications/n1/read")
        assert resp.status_code == 200
        assert resp.json()["data"]["marked"] is True


class TestMarkAllRead:
    def test_marks_all_read(self, client):
        resp = client.post("/api/v1/notifications/read-all")
        assert resp.status_code == 200
        assert resp.json()["data"]["markedCount"] == 3
