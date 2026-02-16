from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/rag", tags=["rag"])


@router.post("/query")
async def rag_query(user_id: CurrentUserId) -> dict:
    """Answer a question using retrieval-augmented generation over user notes."""
    return {"message": "Not implemented yet"}
