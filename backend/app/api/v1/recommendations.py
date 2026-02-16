from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/")
async def get_ranked_feed(user_id: CurrentUserId) -> dict:
    """Get a ranked recommendation feed for the current user."""
    return {"message": "Not implemented yet"}


@router.post("/refresh")
async def force_recalculation(user_id: CurrentUserId) -> dict:
    """Force recalculation of the user's recommendation scores."""
    return {"message": "Not implemented yet"}
