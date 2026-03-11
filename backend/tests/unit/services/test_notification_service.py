"""Unit tests for NotificationService."""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import AsyncMock

import pytest

from app.models.common import NotificationType
from app.models.notification import FcmNotificationData
from app.services.notification.notification_service import NotificationService


@dataclass
class _MockNotification:
    id: str = "n1"
    title: str = "Test Notification"
    body: str = "Test body"
    type: NotificationType = NotificationType.NEW_CONTENT
    is_read: bool = False
    data: dict = field(default_factory=dict)

    def model_dump(self, **kwargs):
        return {
            "id": self.id,
            "title": self.title,
            "body": self.body,
            "type": self.type.value,
            "isRead": self.is_read,
            "data": self.data,
        }


def _make_service():
    notification_repo = AsyncMock()
    notification_sender = AsyncMock()

    notification_repo.list = AsyncMock(
        return_value=([_MockNotification()], None)
    )
    notification_repo.mark_read = AsyncMock()
    notification_repo.mark_all_read = AsyncMock(return_value=5)
    notification_repo.create = AsyncMock(return_value="new-notif-id")

    notification_sender.send = AsyncMock(return_value=True)

    service = NotificationService(
        notification_repo=notification_repo,
        notification_sender=notification_sender,
    )
    return service, notification_repo, notification_sender


class TestListNotifications:
    @pytest.mark.asyncio
    async def test_returns_notifications(self):
        service, _, _ = _make_service()
        notifications, cursor = await service.list_notifications("user1")

        assert len(notifications) == 1
        assert notifications[0].title == "Test Notification"
        assert cursor is None


class TestMarkRead:
    @pytest.mark.asyncio
    async def test_marks_single_read(self):
        service, repo, _ = _make_service()
        await service.mark_read("user1", "n1")
        repo.mark_read.assert_called_once_with("user1", "n1")


class TestMarkAllRead:
    @pytest.mark.asyncio
    async def test_marks_all_read(self):
        service, repo, _ = _make_service()
        count = await service.mark_all_read("user1")

        assert count == 5
        repo.mark_all_read.assert_called_once_with("user1")


class TestCreateAndPush:
    @pytest.mark.asyncio
    async def test_creates_and_pushes(self):
        service, repo, sender = _make_service()
        fcm_data = FcmNotificationData(
            type=NotificationType.NEW_CONTENT, route="/shorts/abc123"
        )
        notif = await service.create_and_push(
            "user1", "Title", "Body", "new_content", fcm_data
        )

        assert notif.id == "new-notif-id"
        repo.create.assert_called_once()
        sender.send.assert_called_once_with(
            "user1", "Title", "Body", data=fcm_data
        )

    @pytest.mark.asyncio
    async def test_stores_notification_even_if_push_fails(self):
        service, repo, sender = _make_service()
        sender.send = AsyncMock(side_effect=Exception("FCM unavailable"))

        notif = await service.create_and_push(
            "user1", "Title", "Body"
        )

        assert notif.id == "new-notif-id"
        repo.create.assert_called_once()
