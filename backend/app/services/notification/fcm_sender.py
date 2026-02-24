"""Firebase Cloud Messaging notification sender.

Implements NotificationSender protocol using firebase-admin SDK.
"""

from __future__ import annotations

import asyncio
import logging
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from app.models.notification import FcmNotificationData

logger = logging.getLogger(__name__)


def _to_str_dict(data: FcmNotificationData | None) -> dict[str, str]:
    """Serialize FcmNotificationData to dict[str, str].

    FCM requires all data values to be strings.
    """
    if data is None:
        return {}
    result: dict[str, str] = {
        "type": data.type.value,
        "route": data.route,
    }
    if data.entity_id is not None:
        result["entityId"] = data.entity_id
    return result


class FCMNotificationSender:
    """FCM push notification sender.

    Implements NotificationSender protocol. Fetches user FCM tokens
    from the user repository and sends push notifications via firebase-admin.

    Args:
        user_repo: User repository to look up FCM tokens.
    """

    def __init__(self, *, user_repo: Any) -> None:
        self._user_repo = user_repo

    async def send(
        self,
        user_id: str,
        title: str,
        body: str,
        data: FcmNotificationData | None = None,
    ) -> bool:
        """Send a push notification to a single user.

        Sends to all registered FCM tokens for the user.
        Returns True if at least one message was sent successfully.
        """
        from firebase_admin import messaging  # noqa: PLC0415

        user = await self._user_repo.get(user_id)
        if not user or not user.fcm_tokens:
            logger.debug("No FCM tokens for user %s, skipping push", user_id)
            return False

        str_data = _to_str_dict(data)
        success = False
        for token in user.fcm_tokens:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data=str_data,
                    token=token,
                )
                await asyncio.to_thread(messaging.send, message)
                success = True
            except messaging.UnregisteredError:
                logger.info("Stale FCM token for user %s, token=%s", user_id, token[:10])
            except Exception as exc:
                logger.warning("FCM send failed for user %s: %s", user_id, exc)

        return success

    async def send_bulk(
        self,
        user_ids: list[str],
        title: str,
        body: str,
        data: FcmNotificationData | None = None,
    ) -> dict[str, bool]:
        """Send push notifications to multiple users.

        Returns a dict mapping user_id to success status.
        """
        results: dict[str, bool] = {}
        for uid in user_ids:
            results[uid] = await self.send(uid, title, body, data)
        return results
