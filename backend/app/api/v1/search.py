from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/search", tags=["search"])


@router.post("/")
async def hybrid_search(user_id: CurrentUserId) -> dict:
    """Perform hybrid search (semantic + keyword) across user content."""
    return {"message": "Not implemented yet"}
