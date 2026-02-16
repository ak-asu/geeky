"""Relationship repository."""
from __future__ import annotations
from typing import Any
from app.models.relationship import RelationshipDocument
from app.repositories.base import FirestoreBaseRepository

class RelationshipRepository(FirestoreBaseRepository[RelationshipDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "relationships", RelationshipDocument)

    async def get_by_source(self, user_id: str, source_id: str) -> list[RelationshipDocument]:
        return await self.query(user_id, filters=[("sourceId", "==", source_id)])

    async def get_by_target(self, user_id: str, target_id: str) -> list[RelationshipDocument]:
        return await self.query(user_id, filters=[("targetId", "==", target_id)])

    async def get_edges_for_concept(self, user_id: str, concept_id: str) -> list[RelationshipDocument]:
        outgoing = await self.get_by_source(user_id, concept_id)
        incoming = await self.get_by_target(user_id, concept_id)
        return outgoing + incoming
