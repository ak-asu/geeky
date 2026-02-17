"""Notifications API routes — list, mark read, bulk mark read."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.middleware.auth import CurrentUserId
from app.dependencies import get_notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/")
async def list_notifications(
    user_id: CurrentUserId,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    service=Depends(get_notification_service),
) -> dict:
    """List notifications for the current user."""
    notifications, next_cursor = await service.list_notifications(
        user_id, limit=limit, cursor=cursor
    )
    return {
        "data": [n.model_dump(mode="json", by_alias=True) for n in notifications],
        "meta": {"cursor": next_cursor, "hasMore": next_cursor is not None},
    }


@router.post("/{notification_id}/read")
async def mark_read(
    notification_id: str,
    user_id: CurrentUserId,
    service=Depends(get_notification_service),
) -> dict:
    """Mark a single notification as read."""
    await service.mark_read(user_id, notification_id)
    return {"data": {"marked": True}}


@router.post("/read-all")
async def mark_all_read(
    user_id: CurrentUserId,
    service=Depends(get_notification_service),
) -> dict:
    """Mark all notifications as read for the current user."""
    count = await service.mark_all_read(user_id)
    return {"data": {"markedCount": count}}
