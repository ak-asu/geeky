"""Short repository."""
from __future__ import annotations
from typing import Any
from app.models.short import ShortDocument
from app.repositories.base import FirestoreBaseRepository

class ShortRepository(FirestoreBaseRepository[ShortDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "shorts", ShortDocument)

    async def get_by_topic(self, user_id: str, topic: str, limit: int = 50) -> list[ShortDocument]:
        return await self.query(user_id, filters=[("topics", "array_contains", topic)], limit=limit)

    async def get_by_chunk_ids(self, user_id: str, chunk_ids: list[str]) -> list[ShortDocument]:
        if not chunk_ids:
            return []
        return await self.query(user_id, filters=[("chunkIds", "array_contains_any", chunk_ids)])
