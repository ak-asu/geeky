"""Bookmarks API routes — create, remove, list bookmarked shorts."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.middleware.auth import CurrentUserId
from app.api.middleware.rate_limit import CheckRateLimit
from app.dependencies import get_bookmark_service

router = APIRouter(prefix="/bookmarks", tags=["bookmarks"])


@router.post("/{short_id}")
async def create_bookmark(
    _rate_limit: CheckRateLimit,
    short_id: str,
    user_id: CurrentUserId,
    service=Depends(get_bookmark_service),
) -> dict:
    """Bookmark a short for later review."""
    result = await service.create_bookmark(user_id, short_id)
    return {"data": result}


@router.delete("/{short_id}")
async def remove_bookmark(
    short_id: str,
    user_id: CurrentUserId,
    service=Depends(get_bookmark_service),
) -> dict:
    """Remove a bookmark from a short."""
    removed = await service.remove_bookmark(user_id, short_id)
    return {"data": {"removed": removed}}


@router.get("")
async def list_bookmarks(
    user_id: CurrentUserId,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    service=Depends(get_bookmark_service),
) -> dict:
    """List all bookmarked shorts for the current user."""
    items, next_cursor = await service.list_bookmarks(
        user_id, limit=limit, cursor=cursor
    )
    return {
        "data": items,
        "meta": {"cursor": next_cursor, "hasMore": next_cursor is not None},
    }
