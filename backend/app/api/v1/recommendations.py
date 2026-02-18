"""Recommendations API routes — ranked feed and refresh."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.middleware.auth import CurrentUserId
from app.dependencies import get_feed_ranker
from app.models.recommendation import ScoredShortResponse

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/")
async def get_ranked_feed(
    user_id: CurrentUserId,
    limit: int = Query(default=20, ge=1, le=100),
    ranker=Depends(get_feed_ranker),
) -> dict:
    """Get a ranked recommendation feed for the current user."""
    feed = await ranker.get_ranked_feed(user_id, limit=limit)
    return {
        "data": [
            ScoredShortResponse(
                shortId=s.short_id,
                score=s.score,
                relevanceScore=s.relevance_score,
                capabilityScore=s.capability_score,
                noveltyScore=s.novelty_score,
                explanation=s.explanation,
            ).model_dump(by_alias=True)
            for s in feed
        ],
    }


@router.post("/refresh")
async def force_recalculation(
    user_id: CurrentUserId,
    ranker=Depends(get_feed_ranker),
) -> dict:
    """Force recalculation of the user's recommendation scores."""
    result = await ranker.refresh(user_id)
    return {"data": result}
