"""User profile API routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.middleware.auth import CurrentUserId, CurrentUserClaims
from app.dependencies import get_profile_service
from app.models.user import UserProfileUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me")
async def get_current_user(
    claims: CurrentUserClaims,
    profile_service=Depends(get_profile_service),
) -> dict:
    """Get the current authenticated user's profile.

    Auto-creates the Firestore document on first sign-in using the identity
    fields (name, email, avatar) carried in the Firebase ID token.
    """
    profile = await profile_service.get_or_create_profile(
        claims.uid,
        name=claims.name,
        email=claims.email,
        avatar_url=claims.avatar_url,
    )
    return {"data": profile.model_dump(mode="json", by_alias=True)}


@router.patch("/me")
async def update_profile(
    claims: CurrentUserClaims,
    body: UserProfileUpdate,
    profile_service=Depends(get_profile_service),
) -> dict:
    """Update the current user's profile fields.

    Auto-creates the Firestore document first if it doesn't exist (upsert),
    so onboarding PATCH calls on first sign-in always succeed.
    """
    updated = await profile_service.update_profile(
        claims.uid,
        body,
        name=claims.name,
        email=claims.email,
        avatar_url=claims.avatar_url,
    )
    return {"data": updated.model_dump(mode="json", by_alias=True)}


@router.get("/me/stats")
async def get_user_stats(
    user_id: CurrentUserId,
    profile_service=Depends(get_profile_service),
) -> dict:
    """Get lightweight learning statistics for the current user."""
    stats = await profile_service.get_stats(user_id)
    return {"data": stats}


@router.post("/me/export")
async def export_user_data(
    user_id: CurrentUserId,
    profile_service=Depends(get_profile_service),
) -> dict:
    """Request a GDPR-compliant data export for the current user."""
    export = await profile_service.export_data(user_id)
    return {"data": export}


@router.delete("/me")
async def delete_account(
    user_id: CurrentUserId,
    profile_service=Depends(get_profile_service),
) -> dict:
    """Permanently delete the current user's account and all associated data."""
    await profile_service.delete_account(user_id)
    return {"data": {"message": "Account deleted successfully"}}
