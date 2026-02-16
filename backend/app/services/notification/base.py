"""Notification sender Protocol."""
from __future__ import annotations
from typing import Protocol

class NotificationSender(Protocol):
    async def send(self, user_id: str, title: str, body: str, data: dict | None = None) -> bool: ...
    async def send_bulk(self, user_ids: list[str], title: str, body: str, data: dict | None = None) -> dict[str, bool]: ...
