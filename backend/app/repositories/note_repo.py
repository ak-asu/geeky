"""Note repository."""
from __future__ import annotations
from typing import Any
from app.models.note import NoteDocument
from app.repositories.base import FirestoreBaseRepository

class NoteRepository(FirestoreBaseRepository[NoteDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "notes", NoteDocument)

    async def get_unprocessed(self, user_id: str, limit: int = 10) -> list[NoteDocument]:
        return await self.query(user_id, filters=[("processed", "==", False)], limit=limit)
