"""Chunk repository."""
from __future__ import annotations
from typing import Any
from app.models.chunk import ChunkDocument
from app.repositories.base import FirestoreBaseRepository

class ChunkRepository(FirestoreBaseRepository[ChunkDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "chunks", ChunkDocument)

    async def get_by_note(self, user_id: str, note_id: str) -> list[ChunkDocument]:
        return await self.query(user_id, filters=[("noteId", "==", note_id)])

    async def delete_by_note(self, user_id: str, note_id: str) -> int:
        chunks = await self.get_by_note(user_id, note_id)
        for chunk in chunks:
            await self.delete(user_id, chunk.id)
        return len(chunks)
