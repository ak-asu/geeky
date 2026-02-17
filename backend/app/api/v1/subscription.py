"""Subscription API routes — tier status and entitlements."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.middleware.auth import CurrentUserId
from app.dependencies import get_user_repository

router = APIRouter(prefix="/subscription", tags=["subscription"])


_ENTITLEMENTS = {
    "free": {
        "maxNotes": 50,
        "maxSources": 3,
        "ragQueriesPerDay": 10,
        "advancedAnalytics": False,
        "priorityProcessing": False,
    },
    "premium": {
        "maxNotes": -1,  # unlimited
        "maxSources": -1,
        "ragQueriesPerDay": -1,
        "advancedAnalytics": True,
        "priorityProcessing": True,
    },
}


@router.get("/status")
async def get_subscription_status(
    user_id: CurrentUserId,
    user_repo=Depends(get_user_repository),
) -> dict:
    """Get the current user's subscription tier and entitlements."""
    user = await user_repo.get(user_id)
    tier = user.subscription_tier.value if user else "free"
    return {
        "data": {
            "tier": tier,
            "entitlements": _ENTITLEMENTS.get(tier, _ENTITLEMENTS["free"]),
        },
    }
