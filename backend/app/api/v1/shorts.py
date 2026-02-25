"""Shorts API routes.

GET /shorts         — List with pagination, filterable by topic/difficulty
GET /shorts/{id}    — Get short detail with engagement stats and citations
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.middleware.auth import CurrentUserId
from app.dependencies import get_short_repository
from app.exceptions import ShortNotFoundError
from app.models.common import PaginatedResponse, PaginationMeta

router = APIRouter(prefix="/shorts", tags=["shorts"])


@router.get("")
async def list_shorts(
    user_id: CurrentUserId,
    limit: int = 50,
    cursor: str | None = None,
    topic: str | None = Query(default=None, description="Filter by topic"),
    min_difficulty: float | None = Query(default=None, ge=0.0, le=1.0),
    max_difficulty: float | None = Query(default=None, ge=0.0, le=1.0),
    short_repo=Depends(get_short_repository),
) -> dict:
    """List shorts with pagination, filterable by topic and difficulty."""
    if topic:
        items = await short_repo.get_by_topic(user_id, topic, limit=limit)
        return PaginatedResponse(
            data=[item.model_dump(mode="json", by_alias=True) for item in items],
            meta=PaginationMeta(has_more=False),
        ).model_dump(mode="json")

    filters: list[tuple[str, str, object]] = []
    if min_difficulty is not None:
        filters.append(("difficulty", ">=", min_difficulty))
    if max_difficulty is not None:
        filters.append(("difficulty", "<=", max_difficulty))

    if filters:
        items = await short_repo.query(user_id, filters=filters, limit=limit)
        return PaginatedResponse(
            data=[item.model_dump(mode="json", by_alias=True) for item in items],
            meta=PaginationMeta(has_more=False),
        ).model_dump(mode="json")

    items, next_cursor = await short_repo.list(user_id, limit=limit, cursor=cursor)
    return PaginatedResponse(
        data=[item.model_dump(mode="json", by_alias=True) for item in items],
        meta=PaginationMeta(cursor=next_cursor, has_more=next_cursor is not None),
    ).model_dump(mode="json")


@router.get("/{short_id}")
async def get_short(
    short_id: str,
    user_id: CurrentUserId,
    short_repo=Depends(get_short_repository),
) -> dict:
    """Get a single short by ID with engagement stats and citations."""
    short = await short_repo.get(user_id, short_id)
    if short is None:
        raise ShortNotFoundError(short_id)

    return {"data": short.model_dump(mode="json", by_alias=True)}
