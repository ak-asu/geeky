"""Relationship (KG edge) repository."""
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

    async def get_all(self, user_id: str) -> list[RelationshipDocument]:
        """Get all edges for graph building."""
        return await self.query(user_id, limit=10000)

    async def get_by_type(self, user_id: str, edge_type: str) -> list[RelationshipDocument]:
        """Get edges of a specific type."""
        return await self.query(user_id, filters=[("type", "==", edge_type)])

    async def find_edge(
        self, user_id: str, source_id: str, target_id: str
    ) -> RelationshipDocument | None:
        """Find a specific edge between two nodes."""
        results = await self.query(
            user_id,
            filters=[("sourceId", "==", source_id), ("targetId", "==", target_id)],
            limit=1,
        )
        return results[0] if results else None

    async def get_by_short(self, user_id: str, short_id: str) -> list[RelationshipDocument]:
        """Get all edges associated with a specific short."""
        return await self.query(user_id, filters=[("shortIds", "array_contains", short_id)])
