"""Interaction repository."""
from __future__ import annotations
from typing import Any
from app.models.interaction import InteractionDocument
from app.repositories.base import FirestoreBaseRepository

class InteractionRepository(FirestoreBaseRepository[InteractionDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "interactions", InteractionDocument)

    async def get_by_article(self, user_id: str, article_id: str) -> list[InteractionDocument]:
        return await self.query(user_id, filters=[("articleId", "==", article_id)])

    async def create_batch(self, user_id: str, interactions: list[InteractionDocument]) -> int:
        count = 0
        for interaction in interactions:
            await self.create(user_id, interaction)
            count += 1
        return count
