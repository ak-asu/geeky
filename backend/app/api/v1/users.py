from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me")
async def get_current_user(user_id: CurrentUserId) -> dict:
    """Get the current authenticated user's profile."""
    return {"message": "Not implemented yet"}


@router.put("/me/profile")
async def update_profile(user_id: CurrentUserId) -> dict:
    """Update the current user's profile fields."""
    return {"message": "Not implemented yet"}


@router.post("/me/export")
async def export_user_data(user_id: CurrentUserId) -> dict:
    """Request a GDPR-compliant data export for the current user."""
    return {"message": "Not implemented yet"}


@router.delete("/me")
async def delete_account(user_id: CurrentUserId) -> dict:
    """Permanently delete the current user's account and all associated data."""
    return {"message": "Not implemented yet"}
