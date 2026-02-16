"""Concept (KG node) repository."""
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

    async def get_by_names(self, user_id: str, names: list[str]) -> list[ConceptDocument]:
        """Get multiple concepts by name. Firestore 'in' query limited to 30."""
        if not names:
            return []
        results: list[ConceptDocument] = []
        for batch in _batches(names, 30):
            results.extend(await self.query(user_id, filters=[("name", "in", batch)]))
        return results

    async def get_by_short(self, user_id: str, short_id: str) -> list[ConceptDocument]:
        """Get all concepts linked to a specific short."""
        return await self.query(user_id, filters=[("shortIds", "array_contains", short_id)])

    async def get_all(self, user_id: str) -> list[ConceptDocument]:
        """Get all concepts for the user (for graph building)."""
        return await self.query(user_id, limit=5000)

    async def add_short_id(self, user_id: str, concept_id: str, short_id: str) -> None:
        """Append a short_id to the concept's shortIds array (atomic)."""
        try:
            from google.cloud.firestore_v1 import ArrayUnion  # noqa: PLC0415
            doc_ref = self._user_collection(user_id).document(concept_id)
            doc_ref.update({"shortIds": ArrayUnion([short_id])})
        except ImportError:
            # Fallback for testing without google-cloud-firestore
            concept = await self.get(user_id, concept_id)
            if concept and short_id not in concept.short_ids:
                concept.short_ids.append(short_id)
                await self.update(user_id, concept_id, {"shortIds": concept.short_ids})


def _batches(items: list, size: int):
    for i in range(0, len(items), size):
        yield items[i : i + size]
