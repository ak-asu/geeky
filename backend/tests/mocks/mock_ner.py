"""Mock NER extractor for testing."""

from __future__ import annotations

from app.services.ner.base import EdgeType, Entity, EntityType, Relation


class MockNERExtractor:
    """Mock NER that extracts simple noun phrases."""

    async def extract_entities(self, text: str) -> list[Entity]:
        # Return a few mock entities based on text length
        words = text.split()[:5]
        return [
            Entity(name=word.strip(".,!?"), type=EntityType.CONCEPT)
            for word in words
            if len(word) > 3
        ]

    async def extract_relations(self, text: str, entities: list[Entity]) -> list[Relation]:
        relations = []
        for i in range(len(entities) - 1):
            relations.append(
                Relation(
                    source=entities[i],
                    target=entities[i + 1],
                    edge_type=EdgeType.RELATED,
                )
            )
        return relations


class MockEdgeClassifier:
    """Mock edge classifier that always returns RELATED."""

    async def classify(
        self, source_name: str, target_name: str, context: str | None = None
    ) -> EdgeType:
        return EdgeType.RELATED
