"""RAG API routes — retrieval-augmented generation (RQ-03, RQ-08)."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.middleware.auth import CurrentUserId
from app.dependencies import get_rag_orchestrator
from app.models.rag import RAGQueryRequest

router = APIRouter(prefix="/rag", tags=["rag"])


@router.post("/query")
async def rag_query(
    user_id: CurrentUserId,
    body: RAGQueryRequest,
    rag=Depends(get_rag_orchestrator),
) -> dict:
    """Answer a question using retrieval-augmented generation over user notes."""
    response = await rag.query(user_id, body)

    return {
        "data": response.model_dump(mode="json", by_alias=True),
    }
