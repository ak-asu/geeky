"""Knowledge Graph builder — constructs user-scoped KGs from Shorts.

Coordinates NER extraction, edge classification, and Firestore storage.
Uses NetworkX for in-memory graph algorithms (KG-01, KG-06).
"""
from __future__ import annotations

import logging
import uuid
from typing import TYPE_CHECKING

from app.models.concept import ConceptDocument
from app.models.relationship import RelationshipDocument
from app.services.ner.base import EdgeType, Entity, EntityType, Relation

if TYPE_CHECKING:
    from app.config import Settings
    from app.repositories.concept_repo import ConceptRepository
    from app.repositories.relationship_repo import RelationshipRepository
    from app.repositories.short_repo import ShortRepository
    from app.services.ner.base import EdgeClassifier, NERExtractor

logger = logging.getLogger(__name__)


class GraphBuilder:
    """Builds and incrementally updates user-scoped knowledge graphs.

    Dependencies injected via constructor:
    - ner_extractor: Extracts entities from short content
    - edge_classifier: Classifies relationships between entity pairs
    - concept_repo: Firestore CRUD for KG nodes
    - relationship_repo: Firestore CRUD for KG edges
    - short_repo: Access to short content
    """

    def __init__(
        self,
        *,
        ner_extractor: NERExtractor,
        edge_classifier: EdgeClassifier,
        concept_repo: ConceptRepository,
        relationship_repo: RelationshipRepository,
        short_repo: ShortRepository,
        settings: Settings,
    ) -> None:
        self._ner = ner_extractor
        self._classifier = edge_classifier
        self._concept_repo = concept_repo
        self._relationship_repo = relationship_repo
        self._short_repo = short_repo
        self._settings = settings

    async def build_for_short(self, user_id: str, short_id: str) -> dict:
        """Incrementally update KG for a single new/updated Short (KG-06).

        Returns summary dict with counts of entities and edges processed.
        """
        short = await self._short_repo.get(user_id, short_id)
        if short is None:
            logger.warning("Short %s not found for user %s", short_id, user_id)
            return {"entities_created": 0, "edges_created": 0}

        text = f"{short.title}\n\n{short.content}"

        # Step 1: Extract entities (KG-02)
        raw_entities = await self._ner.extract_entities(text)
        entities = [
            e for e in raw_entities
            if e.confidence >= self._settings.kg_ner_confidence_threshold
        ][:self._settings.kg_max_entities_per_short]

        if not entities:
            logger.info("No entities extracted from short %s", short_id)
            return {"entities_created": 0, "edges_created": 0}

        # Step 2: Upsert concept nodes
        concept_ids = await self._upsert_concepts(user_id, entities, short_id)

        # Step 3: Extract and classify edges (KG-03)
        relations = await self._ner.extract_relations(text, entities)
        edges_created = await self._upsert_edges(
            user_id, relations, concept_ids, short_id
        )

        logger.info(
            "KG updated for short %s: %d concepts, %d edges",
            short_id, len(concept_ids), edges_created,
        )
        return {"entities_created": len(concept_ids), "edges_created": edges_created}

    async def rebuild_for_user(self, user_id: str) -> dict:
        """Full KG rebuild for a user — re-process all shorts."""
        shorts, _ = await self._short_repo.list(user_id, limit=5000)
        total_entities = 0
        total_edges = 0

        for short in shorts:
            result = await self.build_for_short(user_id, short.id)
            total_entities += result["entities_created"]
            total_edges += result["edges_created"]

        logger.info(
            "Full KG rebuild for user %s: %d shorts, %d entities, %d edges",
            user_id, len(shorts), total_entities, total_edges,
        )
        return {
            "shorts_processed": len(shorts),
            "entities_created": total_entities,
            "edges_created": total_edges,
        }

    async def _upsert_concepts(
        self, user_id: str, entities: list[Entity], short_id: str
    ) -> dict[str, str]:
        """Create or update concept documents. Returns name->id mapping."""
        entity_names = [e.name for e in entities]
        existing = await self._concept_repo.get_by_names(user_id, entity_names)
        existing_map = {c.name.lower(): c for c in existing}

        concept_ids: dict[str, str] = {}

        for entity in entities:
            name_lower = entity.name.lower()
            existing_concept = existing_map.get(name_lower)

            if existing_concept:
                # Update: add short_id reference if not present
                concept_ids[name_lower] = existing_concept.id
                if short_id not in (existing_concept.short_ids or []):
                    await self._concept_repo.add_short_id(
                        user_id, existing_concept.id, short_id
                    )
            else:
                # Create new concept node
                concept_id = str(uuid.uuid4())
                doc = ConceptDocument(
                    id=concept_id,
                    name=entity.name,
                    entity_type=entity.type.value,
                    aliases=entity.aliases,
                    short_ids=[short_id],
                    importance_score=entity.confidence,
                )
                await self._concept_repo.create(user_id, doc, doc_id=concept_id)
                concept_ids[name_lower] = concept_id
                existing_map[name_lower] = doc

        return concept_ids

    async def _upsert_edges(
        self,
        user_id: str,
        relations: list[Relation],
        concept_ids: dict[str, str],
        short_id: str,
    ) -> int:
        """Create or update edge documents. Returns count of edges created."""
        edges_created = 0

        for relation in relations:
            src_name = relation.source.name.lower()
            tgt_name = relation.target.name.lower()

            src_id = concept_ids.get(src_name)
            tgt_id = concept_ids.get(tgt_name)

            if not src_id or not tgt_id or src_id == tgt_id:
                continue

            if relation.confidence < self._settings.kg_edge_confidence_threshold:
                continue

            # Check if edge already exists
            existing = await self._relationship_repo.find_edge(user_id, src_id, tgt_id)

            if existing:
                # Update strength (average) and add short reference
                new_strength = (existing.strength + relation.confidence) / 2
                update_data: dict = {"strength": new_strength}
                if short_id not in (existing.short_ids or []):
                    try:
                        from google.cloud.firestore_v1 import ArrayUnion  # noqa: PLC0415
                        update_data["shortIds"] = ArrayUnion([short_id])
                    except ImportError:
                        update_data["shortIds"] = (existing.short_ids or []) + [short_id]
                await self._relationship_repo.update(user_id, existing.id, update_data)
            else:
                # Create new edge
                edge_id = str(uuid.uuid4())
                doc = RelationshipDocument(
                    id=edge_id,
                    source_id=src_id,
                    target_id=tgt_id,
                    type=relation.edge_type.value,
                    strength=relation.confidence,
                    confidence=relation.confidence,
                    evidence=relation.context[:500] if relation.context else None,
                    short_ids=[short_id],
                )
                await self._relationship_repo.create(user_id, doc, doc_id=edge_id)
                edges_created += 1

        return edges_created
