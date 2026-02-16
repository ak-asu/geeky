"""Notification Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import NotificationType, TimestampMixin


class NotificationDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    title: str = ""
    body: str = ""
    type: NotificationType = NotificationType.NEW_CONTENT
    is_read: bool = Field(default=False, alias="isRead")
    data: dict = Field(default_factory=dict)
