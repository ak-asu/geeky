from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/")
async def list_notifications(user_id: CurrentUserId) -> dict:
    """List notifications for the current user."""
    return {"message": "Not implemented yet"}


@router.post("/{notification_id}/read")
async def mark_read(
    notification_id: str, user_id: CurrentUserId
) -> dict:
    """Mark a single notification as read."""
    return {"message": "Not implemented yet"}


@router.post("/read-all")
async def mark_all_read(user_id: CurrentUserId) -> dict:
    """Mark all notifications as read for the current user."""
    return {"message": "Not implemented yet"}
