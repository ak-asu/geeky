from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/dashboard")
async def get_dashboard(user_id: CurrentUserId) -> dict:
    """Get the analytics dashboard snapshot for the current user."""
    return {"message": "Not implemented yet"}


@router.get("/achievements")
async def get_achievements(user_id: CurrentUserId) -> dict:
    """Get the user's achievements and progress milestones."""
    return {"message": "Not implemented yet"}
