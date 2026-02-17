"""Module service — CRUD for learning modules.

Handles creation, listing, updating, and deletion of learning modules
which group shorts into structured learning paths.
"""

from __future__ import annotations

import logging
from typing import Any

from app.exceptions import ModuleNotFoundError
from app.models.module import ModuleCreate, ModuleDocument, ModuleUpdate

logger = logging.getLogger(__name__)


class ModuleService:
    """Learning module management service.

    Args:
        module_repo: Module document repository.
        short_repo: Short repository (for total_shorts computation).
    """

    def __init__(
        self,
        *,
        module_repo: Any,
        short_repo: Any,
    ) -> None:
        self._module_repo = module_repo
        self._short_repo = short_repo

    async def create_module(
        self, user_id: str, data: ModuleCreate
    ) -> ModuleDocument:
        """Create a new learning module.

        Computes total_shorts from the provided short_ids list.
        """
        module = ModuleDocument(
            name=data.name,
            description=data.description,
            topics=data.topics,
            short_ids=data.short_ids,
            type=data.type,
            is_free=data.is_free,
            total_shorts=len(data.short_ids),
        )

        doc_id = await self._module_repo.create(user_id, module)
        module.id = doc_id
        return module

    async def list_modules(
        self, user_id: str, limit: int = 50, cursor: str | None = None
    ) -> tuple[list[ModuleDocument], str | None]:
        """List modules with cursor-based pagination."""
        return await self._module_repo.list(user_id, limit=limit, cursor=cursor)

    async def get_module(self, user_id: str, module_id: str) -> ModuleDocument:
        """Get a single module by ID."""
        module = await self._module_repo.get(user_id, module_id)
        if not module:
            raise ModuleNotFoundError(module_id)
        return module

    async def update_module(
        self, user_id: str, module_id: str, data: ModuleUpdate
    ) -> ModuleDocument:
        """Partial update of a module.

        Recomputes total_shorts if short_ids changes.
        """
        module = await self._module_repo.get(user_id, module_id)
        if not module:
            raise ModuleNotFoundError(module_id)

        update_data = data.model_dump(exclude_none=True, mode="json", by_alias=True)

        # Recompute total_shorts if short_ids is being updated
        if "shortIds" in update_data:
            update_data["totalShorts"] = len(update_data["shortIds"])

        if update_data:
            await self._module_repo.update(user_id, module_id, update_data)

        return await self.get_module(user_id, module_id)

    async def delete_module(self, user_id: str, module_id: str) -> None:
        """Delete a module by ID."""
        module = await self._module_repo.get(user_id, module_id)
        if not module:
            raise ModuleNotFoundError(module_id)
        await self._module_repo.delete(user_id, module_id)
