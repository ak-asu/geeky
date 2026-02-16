"""Notification repository."""
from __future__ import annotations
from typing import Any
from app.models.notification import NotificationDocument
from app.repositories.base import FirestoreBaseRepository

class NotificationRepository(FirestoreBaseRepository[NotificationDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "notifications", NotificationDocument)

    async def get_unread(self, user_id: str, limit: int = 50) -> list[NotificationDocument]:
        return await self.query(user_id, filters=[("isRead", "==", False)], limit=limit)

    async def mark_read(self, user_id: str, notification_id: str) -> None:
        await self.update(user_id, notification_id, {"isRead": True})

    async def mark_all_read(self, user_id: str) -> int:
        unread = await self.get_unread(user_id, limit=500)
        for notif in unread:
            await self.mark_read(user_id, notif.id)
        return len(unread)
