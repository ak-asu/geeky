"""Notification service — manage in-app notifications with optional push.

Handles listing, read marking, creation, and FCM push delivery.
"""

from __future__ import annotations

import logging
from typing import Any

from app.models.notification import NotificationDocument

logger = logging.getLogger(__name__)


class NotificationService:
    """In-app notification management with optional push delivery.

    Args:
        notification_repo: Notification document repository.
        notification_sender: FCM push sender (implements NotificationSender protocol).
    """

    def __init__(
        self,
        *,
        notification_repo: Any,
        notification_sender: Any,
    ) -> None:
        self._notification_repo = notification_repo
        self._notification_sender = notification_sender

    async def list_notifications(
        self, user_id: str, limit: int = 50, cursor: str | None = None
    ) -> tuple[list[NotificationDocument], str | None]:
        """List notifications with cursor-based pagination."""
        return await self._notification_repo.list(
            user_id, limit=limit, cursor=cursor
        )

    async def mark_read(self, user_id: str, notification_id: str) -> None:
        """Mark a single notification as read."""
        await self._notification_repo.mark_read(user_id, notification_id)

    async def mark_all_read(self, user_id: str) -> int:
        """Mark all unread notifications as read.

        Returns the count of notifications that were marked.
        """
        return await self._notification_repo.mark_all_read(user_id)

    async def create_and_push(
        self,
        user_id: str,
        title: str,
        body: str,
        notification_type: str = "new_content",
        data: dict | None = None,
    ) -> NotificationDocument:
        """Create an in-app notification and push via FCM.

        Creates a persistent notification document and attempts FCM delivery.
        Push failure does not prevent the in-app notification from being stored.
        """
        from app.models.common import NotificationType  # noqa: PLC0415

        notif = NotificationDocument(
            title=title,
            body=body,
            type=NotificationType(notification_type),
            data=data or {},
        )

        doc_id = await self._notification_repo.create(user_id, notif)
        notif.id = doc_id

        # Push via FCM (best-effort)
        try:
            await self._notification_sender.send(
                user_id, title, body, data=data
            )
        except Exception as exc:
            logger.warning(
                "FCM push failed for user %s, notification %s: %s",
                user_id, doc_id, exc,
            )

        return notif
