"""Notification Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel, NotificationType, TimestampMixin


class FcmNotificationData(GeekyBaseModel):
    """Typed FCM data payload.

    All values serialised to strings before sending — FCM requires dict[str, str].
    """

    type: NotificationType = NotificationType.NEW_CONTENT
    route: str = Field(default="", description="Deep-link route, e.g. /shorts/abc123")
    entity_id: str | None = Field(default=None, alias="entityId")


class NotificationDocument(TimestampMixin):
    id: str = ""
    title: str = ""
    body: str = ""
    type: NotificationType = NotificationType.NEW_CONTENT
    is_read: bool = Field(default=False, alias="isRead")
    data: FcmNotificationData | None = None
