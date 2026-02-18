"""RAG API routes — retrieval-augmented generation (RQ-03, RQ-08)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.api.middleware.auth import CurrentUserId
from app.api.middleware.rate_limit import CheckRateLimit
from app.dependencies import get_feature_flags, get_rag_orchestrator, get_text_sanitizer
from app.models.rag import RAGQueryRequest

router = APIRouter(prefix="/rag", tags=["rag"])


@router.post("/query")
async def rag_query(
    _rate_limit: CheckRateLimit,
    user_id: CurrentUserId,
    body: RAGQueryRequest,
    rag=Depends(get_rag_orchestrator),
    sanitizer=Depends(get_text_sanitizer),
    flags=Depends(get_feature_flags),
) -> dict:
    """Answer a question using retrieval-augmented generation over user notes."""
    if not await flags.is_enabled("rag_enabled", default=True):
        raise HTTPException(status_code=503, detail="RAG service is temporarily disabled")
    body.question = sanitizer.sanitize(body.question)
    response = await rag.query(user_id, body)

    return {
        "data": response.model_dump(mode="json", by_alias=True),
    }
