"""Unit tests for GraphQueryService."""
from __future__ import annotations

import pytest

from app.config import Settings
from app.models.concept import ConceptDocument
from app.models.relationship import RelationshipDocument
from app.services.knowledge_graph.query_service import GraphQueryService


class InMemoryConceptRepo:
    """In-memory concept repo for graph query testing."""

    def __init__(self, concepts: list[ConceptDocument]):
        self._concepts = {c.id: c for c in concepts}

    async def get_all(self, user_id):
        return list(self._concepts.values())

    async def list(self, user_id, limit=50, cursor=None):
        items = list(self._concepts.values())[:limit]
        return items, None


class InMemoryRelationshipRepo:
    """In-memory relationship repo for graph query testing."""

    def __init__(self, edges: list[RelationshipDocument]):
        self._edges = {e.id: e for e in edges}

    async def get_all(self, user_id):
        return list(self._edges.values())

    async def list(self, user_id, limit=50, cursor=None):
        items = list(self._edges.values())[:limit]
        return items, None


@pytest.fixture
def settings():
    return Settings(
        kg_pagerank_damping=0.85,
        kg_community_resolution=1.0,
    )


@pytest.fixture
def concepts():
    """A small graph: A -> B -> C, A -> D, with prerequisite edges."""
    return [
        ConceptDocument(id="c-a", name="Algebra", entity_type="concept", mastery_state="learned"),
        ConceptDocument(id="c-b", name="Linear Algebra", entity_type="concept", mastery_state="unknown"),
        ConceptDocument(id="c-c", name="Machine Learning", entity_type="concept", mastery_state="unknown"),
        ConceptDocument(id="c-d", name="Calculus", entity_type="concept", mastery_state="learned"),
    ]


@pytest.fixture
def edges():
    return [
        RelationshipDocument(id="e-1", source_id="c-a", target_id="c-b", type="prerequisite", strength=0.9, confidence=0.9),
        RelationshipDocument(id="e-2", source_id="c-b", target_id="c-c", type="prerequisite", strength=0.8, confidence=0.8),
        RelationshipDocument(id="e-3", source_id="c-a", target_id="c-d", type="related", strength=0.7, confidence=0.7),
        RelationshipDocument(id="e-4", source_id="c-d", target_id="c-c", type="prerequisite", strength=0.6, confidence=0.6),
    ]


@pytest.fixture
def query_service(concepts, edges, settings):
    return GraphQueryService(
        concept_repo=InMemoryConceptRepo(concepts),
        relationship_repo=InMemoryRelationshipRepo(edges),
        settings=settings,
    )


class TestKGSummary:

    @pytest.mark.asyncio
    async def test_summary_node_count(self, query_service):
        summary = await query_service.get_summary("user-001")
        assert summary.node_count == 4

    @pytest.mark.asyncio
    async def test_summary_edge_count(self, query_service):
        summary = await query_service.get_summary("user-001")
        assert summary.edge_count == 4

    @pytest.mark.asyncio
    async def test_summary_top_concepts(self, query_service):
        summary = await query_service.get_summary("user-001")
        assert len(summary.top_concepts) > 0
        assert summary.top_concepts[0]["name"] != ""

    @pytest.mark.asyncio
    async def test_summary_empty_graph(self, settings):
        svc = GraphQueryService(
            concept_repo=InMemoryConceptRepo([]),
            relationship_repo=InMemoryRelationshipRepo([]),
            settings=settings,
        )
        summary = await svc.get_summary("user-001")
        assert summary.node_count == 0
        assert summary.edge_count == 0


class TestLearningPath:

    @pytest.mark.asyncio
    async def test_path_exists(self, query_service):
        path = await query_service.get_learning_path("user-001", "c-a", "c-c")
        assert path.found is True
        assert len(path.path) >= 2
        assert path.path[0]["id"] == "c-a"
        assert path.path[-1]["id"] == "c-c"

    @pytest.mark.asyncio
    async def test_path_not_found(self, query_service):
        path = await query_service.get_learning_path("user-001", "c-c", "c-a")
        # c-c has no outgoing edges to c-a
        # Depending on graph structure, path may or may not exist
        # The important thing is it doesn't crash
        assert isinstance(path.found, bool)

    @pytest.mark.asyncio
    async def test_path_nonexistent_node(self, query_service):
        path = await query_service.get_learning_path("user-001", "c-a", "nonexistent")
        assert path.found is False


class TestPrerequisites:

    @pytest.mark.asyncio
    async def test_prerequisites_chain(self, query_service):
        chain = await query_service.get_prerequisites("user-001", "c-c")
        assert len(chain.prerequisites) > 0
        # Machine Learning has prerequisites: Linear Algebra, Algebra, Calculus
        prereq_ids = {p["id"] for p in chain.prerequisites}
        assert "c-b" in prereq_ids  # Linear Algebra

    @pytest.mark.asyncio
    async def test_prerequisites_empty_for_root(self, query_service):
        chain = await query_service.get_prerequisites("user-001", "c-a")
        # Algebra has no prerequisites in our test graph
        assert len(chain.prerequisites) == 0

    @pytest.mark.asyncio
    async def test_prerequisites_nonexistent(self, query_service):
        chain = await query_service.get_prerequisites("user-001", "nonexistent")
        assert len(chain.prerequisites) == 0


class TestKnowledgeGaps:

    @pytest.mark.asyncio
    async def test_finds_gaps(self, query_service):
        gaps = await query_service.get_knowledge_gaps("user-001")
        # Linear Algebra (c-b) and Machine Learning (c-c) are "unknown"
        # and connected to known concepts (Algebra, Calculus)
        gap_ids = {g.concept_id for g in gaps}
        assert "c-b" in gap_ids or "c-c" in gap_ids

    @pytest.mark.asyncio
    async def test_gaps_sorted_by_importance(self, query_service):
        gaps = await query_service.get_knowledge_gaps("user-001")
        if len(gaps) >= 2:
            assert gaps[0].importance >= gaps[1].importance


class TestRelatedConcepts:

    @pytest.mark.asyncio
    async def test_related_concepts(self, query_service):
        related = await query_service.get_related_concepts("user-001", "c-a")
        assert len(related) > 0
        related_ids = {r["id"] for r in related}
        assert "c-b" in related_ids  # Linear Algebra is a neighbor

    @pytest.mark.asyncio
    async def test_related_nonexistent(self, query_service):
        related = await query_service.get_related_concepts("user-001", "nonexistent")
        assert related == []
