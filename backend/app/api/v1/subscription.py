"""Subscription API routes — tier status and entitlements."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.middleware.auth import CurrentUserId
from app.dependencies import get_user_repository
from app.models.subscription import ENTITLEMENTS

router = APIRouter(prefix="/subscription", tags=["subscription"])


@router.get("/status")
async def get_subscription_status(
    user_id: CurrentUserId,
    user_repo=Depends(get_user_repository),
) -> dict:
    """Get the current user's subscription tier and entitlements."""
    user = await user_repo.get(user_id)
    tier = user.subscription_tier.value if user else "free"
    entitlements = ENTITLEMENTS.get(tier, ENTITLEMENTS["free"])
    return {
        "data": {
            "tier": tier,
            "entitlements": entitlements.model_dump(by_alias=True),
        },
    }
