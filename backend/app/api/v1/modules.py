from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/modules", tags=["modules"])


@router.post("/")
async def create_module(user_id: CurrentUserId) -> dict:
    """Create a new learning module."""
    return {"message": "Not implemented yet"}


@router.get("/")
async def list_modules(user_id: CurrentUserId) -> dict:
    """List all modules for the current user."""
    return {"message": "Not implemented yet"}


@router.get("/{module_id}")
async def get_module(module_id: str, user_id: CurrentUserId) -> dict:
    """Get a single module by ID."""
    return {"message": "Not implemented yet"}


@router.put("/{module_id}")
async def update_module(module_id: str, user_id: CurrentUserId) -> dict:
    """Update an existing module."""
    return {"message": "Not implemented yet"}


@router.delete("/{module_id}")
async def delete_module(module_id: str, user_id: CurrentUserId) -> dict:
    """Delete a module."""
    return {"message": "Not implemented yet"}
