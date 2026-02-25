"""Modules API routes — CRUD for learning modules."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.middleware.auth import CurrentUserId
from app.api.middleware.rate_limit import CheckRateLimit
from app.dependencies import get_module_service
from app.models.module import ModuleCreate, ModuleUpdate

router = APIRouter(prefix="/modules", tags=["modules"])


@router.post("")
async def create_module(
    _rate_limit: CheckRateLimit,
    data: ModuleCreate,
    user_id: CurrentUserId,
    service=Depends(get_module_service),
) -> dict:
    """Create a new learning module."""
    module = await service.create_module(user_id, data)
    return {"data": module.model_dump(mode="json", by_alias=True)}


@router.get("")
async def list_modules(
    user_id: CurrentUserId,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    service=Depends(get_module_service),
) -> dict:
    """List all modules for the current user."""
    modules, next_cursor = await service.list_modules(
        user_id, limit=limit, cursor=cursor
    )
    return {
        "data": [m.model_dump(mode="json", by_alias=True) for m in modules],
        "meta": {"cursor": next_cursor, "hasMore": next_cursor is not None},
    }


@router.get("/{module_id}")
async def get_module(
    module_id: str,
    user_id: CurrentUserId,
    service=Depends(get_module_service),
) -> dict:
    """Get a single module by ID."""
    module = await service.get_module(user_id, module_id)
    return {"data": module.model_dump(mode="json", by_alias=True)}


@router.patch("/{module_id}")
async def update_module(
    _rate_limit: CheckRateLimit,
    module_id: str,
    data: ModuleUpdate,
    user_id: CurrentUserId,
    service=Depends(get_module_service),
) -> dict:
    """Update an existing module (partial update)."""
    module = await service.update_module(user_id, module_id, data)
    return {"data": module.model_dump(mode="json", by_alias=True)}


@router.delete("/{module_id}")
async def delete_module(
    module_id: str,
    user_id: CurrentUserId,
    service=Depends(get_module_service),
) -> dict:
    """Delete a module."""
    await service.delete_module(user_id, module_id)
    return {"data": {"deleted": True}}
