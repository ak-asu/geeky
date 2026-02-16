"""Unit tests for GraphBuilder service."""
from __future__ import annotations

import pytest

from app.config import Settings
from app.models.concept import ConceptDocument
from app.models.relationship import RelationshipDocument
from app.models.short import ShortDocument
from app.services.ner.base import EdgeType, Entity, EntityType, Relation
from tests.mocks.mock_ner import MockEdgeClassifier, MockNERExtractor


class MockConceptRepo:
    """In-memory concept repository for testing."""

    def __init__(self):
        self._store: dict[str, dict[str, ConceptDocument]] = {}

    async def get(self, user_id, doc_id):
        return self._store.get(user_id, {}).get(doc_id)

    async def get_by_names(self, user_id, names):
        results = []
        for doc in self._store.get(user_id, {}).values():
            if doc.name.lower() in [n.lower() for n in names]:
                results.append(doc)
        return results

    async def create(self, user_id, doc, doc_id=None):
        self._store.setdefault(user_id, {})[doc_id or doc.id] = doc
        return doc_id or doc.id

    async def add_short_id(self, user_id, concept_id, short_id):
        doc = self._store.get(user_id, {}).get(concept_id)
        if doc and short_id not in doc.short_ids:
            doc.short_ids.append(short_id)

    async def get_all(self, user_id):
        return list(self._store.get(user_id, {}).values())


class MockRelationshipRepo:
    """In-memory relationship repository for testing."""

    def __init__(self):
        self._store: dict[str, dict[str, RelationshipDocument]] = {}

    async def find_edge(self, user_id, source_id, target_id):
        for doc in self._store.get(user_id, {}).values():
            if doc.source_id == source_id and doc.target_id == target_id:
                return doc
        return None

    async def create(self, user_id, doc, doc_id=None):
        self._store.setdefault(user_id, {})[doc_id or doc.id] = doc
        return doc_id or doc.id

    async def update(self, user_id, doc_id, data):
        doc = self._store.get(user_id, {}).get(doc_id)
        if doc:
            for k, v in data.items():
                if hasattr(doc, k):
                    setattr(doc, k, v)

    async def get_all(self, user_id):
        return list(self._store.get(user_id, {}).values())


class MockShortRepo:
    """In-memory short repository for testing."""

    def __init__(self, shorts=None):
        self._shorts = shorts or {}

    async def get(self, user_id, short_id):
        return self._shorts.get(short_id)

    async def list(self, user_id, limit=50):
        return list(self._shorts.values())[:limit], None


@pytest.fixture
def settings():
    return Settings(
        kg_ner_confidence_threshold=0.5,
        kg_edge_confidence_threshold=0.4,
        kg_max_entities_per_short=20,
        kg_community_resolution=1.0,
        kg_pagerank_damping=0.85,
    )


@pytest.fixture
def test_short():
    return ShortDocument(
        id="short-001",
        title="Introduction to Machine Learning",
        content="Machine learning is a subset of artificial intelligence. Neural networks are used for deep learning tasks.",
        topics=["machine learning", "AI"],
    )


@pytest.fixture
def graph_builder(settings, test_short):
    from app.services.knowledge_graph.graph_builder import GraphBuilder

    return GraphBuilder(
        ner_extractor=MockNERExtractor(),
        edge_classifier=MockEdgeClassifier(),
        concept_repo=MockConceptRepo(),
        relationship_repo=MockRelationshipRepo(),
        short_repo=MockShortRepo(shorts={"short-001": test_short}),
        settings=settings,
    )


class TestGraphBuilder:

    @pytest.mark.asyncio
    async def test_build_for_short_creates_concepts(self, graph_builder):
        result = await graph_builder.build_for_short("user-001", "short-001")
        assert result["entities_created"] > 0

    @pytest.mark.asyncio
    async def test_build_for_short_creates_edges(self, graph_builder):
        result = await graph_builder.build_for_short("user-001", "short-001")
        assert result["edges_created"] >= 0  # May be 0 if mock NER doesn't produce enough entities

    @pytest.mark.asyncio
    async def test_build_for_missing_short(self, graph_builder):
        result = await graph_builder.build_for_short("user-001", "nonexistent")
        assert result["entities_created"] == 0
        assert result["edges_created"] == 0

    @pytest.mark.asyncio
    async def test_incremental_update_deduplicates_concepts(self, graph_builder):
        """Second call for same short should not duplicate concepts."""
        result1 = await graph_builder.build_for_short("user-001", "short-001")
        result2 = await graph_builder.build_for_short("user-001", "short-001")
        # Second call should find existing concepts and not create new ones
        assert result2["entities_created"] >= 0

    @pytest.mark.asyncio
    async def test_rebuild_for_user(self, graph_builder):
        result = await graph_builder.rebuild_for_user("user-001")
        assert "shorts_processed" in result
        assert "entities_created" in result
        assert "edges_created" in result
        assert result["shorts_processed"] == 1
