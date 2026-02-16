from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/sources", tags=["sources"])


@router.post("/")
async def add_source(user_id: CurrentUserId) -> dict:
    """Add a new external source (URL, PDF, etc.)."""
    return {"message": "Not implemented yet"}


@router.get("/")
async def list_sources(user_id: CurrentUserId) -> dict:
    """List all sources for the current user."""
    return {"message": "Not implemented yet"}


@router.delete("/{source_id}")
async def remove_source(source_id: str, user_id: CurrentUserId) -> dict:
    """Remove a source."""
    return {"message": "Not implemented yet"}


@router.post("/{source_id}/check")
async def check_source_health(
    source_id: str, user_id: CurrentUserId
) -> dict:
    """Check if a source URL is still reachable and content is unchanged."""
    return {"message": "Not implemented yet"}
