"""Sync API routes — batch upload offline interactions."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.middleware.auth import CurrentUserId
from app.dependencies import get_sync_service
from app.models.interaction import InteractionBatchRequest

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/interactions")
async def batch_upload_interactions(
    data: InteractionBatchRequest,
    user_id: CurrentUserId,
    service=Depends(get_sync_service),
) -> dict:
    """Batch upload offline interaction events (views, taps, swipes, etc.)."""
    result = await service.batch_sync(user_id, data.interactions)
    return {"data": result}
