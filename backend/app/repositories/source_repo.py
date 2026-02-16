"""Source repository."""
from __future__ import annotations
from typing import Any
from app.models.source import SourceDocument
from app.repositories.base import FirestoreBaseRepository

class SourceRepository(FirestoreBaseRepository[SourceDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "sources", SourceDocument)

    async def get_active(self, user_id: str) -> list[SourceDocument]:
        return await self.query(user_id, filters=[("status", "==", "active")])
