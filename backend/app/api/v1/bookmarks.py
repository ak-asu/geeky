from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/bookmarks", tags=["bookmarks"])


@router.post("/{short_id}")
async def create_bookmark(short_id: str, user_id: CurrentUserId) -> dict:
    """Bookmark a short for later review."""
    return {"message": "Not implemented yet"}


@router.delete("/{short_id}")
async def remove_bookmark(short_id: str, user_id: CurrentUserId) -> dict:
    """Remove a bookmark from a short."""
    return {"message": "Not implemented yet"}


@router.get("/")
async def list_bookmarks(user_id: CurrentUserId) -> dict:
    """List all bookmarked shorts for the current user."""
    return {"message": "Not implemented yet"}
