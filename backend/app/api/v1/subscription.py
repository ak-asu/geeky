from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/subscription", tags=["subscription"])


@router.get("/status")
async def get_subscription_status(user_id: CurrentUserId) -> dict:
    """Get the current user's subscription tier and entitlements."""
    return {"message": "Not implemented yet"}
