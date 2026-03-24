"""Search API routes — hybrid search (RQ-01)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.middleware.auth import CurrentUserId
from app.api.middleware.rate_limit import CheckRateLimit
from app.dependencies import get_hybrid_search_service
from app.models.rag import SearchRequest

router = APIRouter(prefix="/search", tags=["search"])


@router.post("")
async def hybrid_search(
    _rate_limit: CheckRateLimit,
    user_id: CurrentUserId,
    body: SearchRequest,
    search_service=Depends(get_hybrid_search_service),
) -> dict:
    """Perform hybrid search (semantic + keyword) across user content."""
    topic = body.filters.topic if body.filters else None
    module_id = body.filters.module_id if body.filters else None

    results = await search_service.search(
        user_id,
        body.query,
        top_k=body.limit,
        topic=topic,
        module_id=module_id,
    )

    return {
        "data": {
            "results": [r.model_dump(mode="json", by_alias=True) for r in results],
            "total": len(results),
        }
    }


@router.get("")
async def search_get(
    _rate_limit: CheckRateLimit,
    user_id: CurrentUserId,
    q: str = Query(..., min_length=1, max_length=500, description="Search query"),
    scope: str = Query(default="all", description="Search scope: all, topic, module"),
    topic: str | None = Query(default=None, description="Filter by topic"),
    limit: int = Query(default=20, ge=1, le=100),
    search_service=Depends(get_hybrid_search_service),
) -> dict:
    """GET endpoint for hybrid search with query parameters."""
    results = await search_service.search(
        user_id,
        q,
        top_k=limit,
        topic=topic,
    )

    return {
        "data": {
            "results": [r.model_dump(mode="json", by_alias=True) for r in results],
            "total": len(results),
        }
    }
