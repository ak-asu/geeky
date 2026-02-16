"""Concept repository."""
from __future__ import annotations
from typing import Any
from app.models.concept import ConceptDocument
from app.repositories.base import FirestoreBaseRepository

class ConceptRepository(FirestoreBaseRepository[ConceptDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "concepts", ConceptDocument)

    async def get_by_name(self, user_id: str, name: str) -> ConceptDocument | None:
        results = await self.query(user_id, filters=[("name", "==", name)], limit=1)
        return results[0] if results else None
