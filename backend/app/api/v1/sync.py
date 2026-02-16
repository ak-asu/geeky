from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/interactions")
async def batch_upload_interactions(user_id: CurrentUserId) -> dict:
    """Batch upload offline interaction events (views, taps, swipes, etc.)."""
    return {"message": "Not implemented yet"}
