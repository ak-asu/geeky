"""Sources API routes — manage external content sources."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.middleware.auth import CurrentUserId
from app.api.middleware.rate_limit import CheckRateLimit
from app.dependencies import get_source_service, get_subscription_service
from app.models.source import SourceCreate

router = APIRouter(prefix="/sources", tags=["sources"])


@router.post("")
async def add_source(
    _rate_limit: CheckRateLimit,
    data: SourceCreate,
    user_id: CurrentUserId,
    service=Depends(get_source_service),
    sub_svc=Depends(get_subscription_service),
) -> dict:
    """Add a new external source (URL, RSS, etc.)."""
    await sub_svc.check_sources_quota(user_id)
    source = await service.add_source(user_id, data)
    return {"data": source.model_dump(mode="json", by_alias=True)}


@router.get("")
async def list_sources(
    user_id: CurrentUserId,
    service=Depends(get_source_service),
) -> dict:
    """List all sources for the current user."""
    sources = await service.list_sources(user_id)
    return {
        "data": [s.model_dump(mode="json", by_alias=True) for s in sources],
    }


@router.delete("/{source_id}")
async def remove_source(
    source_id: str,
    user_id: CurrentUserId,
    service=Depends(get_source_service),
) -> dict:
    """Remove a source."""
    await service.remove_source(user_id, source_id)
    return {"data": {"deleted": True}}


@router.post("/{source_id}/check")
async def check_source_health(
    source_id: str,
    user_id: CurrentUserId,
    service=Depends(get_source_service),
) -> dict:
    """Check if a source URL is still reachable and content is unchanged."""
    result = await service.check_health(user_id, source_id)
    return {"data": result}
