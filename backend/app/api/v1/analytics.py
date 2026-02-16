"""Analytics API routes — dashboard, streak, mastery (AN-01, AN-02, AN-03)."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.middleware.auth import CurrentUserId
from app.dependencies import get_analytics_aggregator

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/dashboard")
async def get_dashboard(
    user_id: CurrentUserId,
    aggregator=Depends(get_analytics_aggregator),
) -> dict:
    """Get the analytics dashboard snapshot for the current user (AN-01)."""
    dashboard = await aggregator.get_dashboard(user_id)
    return {"data": dashboard.model_dump(mode="json", by_alias=True)}


@router.get("/streak")
async def get_streak(
    user_id: CurrentUserId,
    aggregator=Depends(get_analytics_aggregator),
) -> dict:
    """Get the user's current study streak (AN-02)."""
    streak = await aggregator.get_streak(user_id)
    return {"data": streak.model_dump(mode="json", by_alias=True)}


@router.get("/mastery")
async def get_mastery(
    user_id: CurrentUserId,
    aggregator=Depends(get_analytics_aggregator),
) -> dict:
    """Get mastery distribution across review states (AN-03)."""
    mastery = await aggregator.get_mastery_distribution(user_id)
    return {"data": mastery.model_dump(mode="json", by_alias=True)}


@router.get("/achievements")
async def get_achievements(
    user_id: CurrentUserId,
    aggregator=Depends(get_analytics_aggregator),
) -> dict:
    """Get the user's achievements and progress milestones."""
    dashboard = await aggregator.get_dashboard(user_id)
    return {
        "data": {
            "achievements": [a.model_dump(mode="json", by_alias=True) for a in dashboard.achievements],
        }
    }
