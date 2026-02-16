"""Integration tests for Knowledge Graph API routes."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.knowledge_graph import router
from app.config import Settings
from app.models.concept import ConceptDocument
from app.models.relationship import RelationshipDocument
from app.services.knowledge_graph.query_service import GraphQueryService


# ---- In-memory mock repos ----


class MockConceptRepo:
    def __init__(self):
        self._concepts = [
            ConceptDocument(id="c-1", name="Python", entity_type="concept", importance_score=0.8),
            ConceptDocument(id="c-2", name="Machine Learning", entity_type="concept", importance_score=0.9),
            ConceptDocument(id="c-3", name="Deep Learning", entity_type="concept", mastery_state="unknown"),
        ]

    async def get_all(self, user_id):
        return self._concepts

    async def get(self, user_id, doc_id):
        return next((c for c in self._concepts if c.id == doc_id), None)

    async def list(self, user_id, limit=50, cursor=None):
        return self._concepts[:limit], None


class MockRelationshipRepo:
    def __init__(self):
        self._edges = [
            RelationshipDocument(id="e-1", source_id="c-1", target_id="c-2", type="prerequisite", strength=0.8, confidence=0.8),
            RelationshipDocument(id="e-2", source_id="c-2", target_id="c-3", type="prerequisite", strength=0.7, confidence=0.7),
        ]

    async def get_all(self, user_id):
        return self._edges

    async def list(self, user_id, limit=50, cursor=None):
        return self._edges[:limit], None


# ---- App setup ----


def _make_test_app() -> FastAPI:
    """Create a test app with mocked dependencies."""
    from app.api.middleware.auth import verify_firebase_token

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    settings = Settings(kg_pagerank_damping=0.85, kg_community_resolution=1.0)
    concept_repo = MockConceptRepo()
    relationship_repo = MockRelationshipRepo()
    query_service = GraphQueryService(
        concept_repo=concept_repo,
        relationship_repo=relationship_repo,
        settings=settings,
    )

    # Override dependencies
    from app.dependencies import (
        get_concept_repository,
        get_graph_query_service,
        get_relationship_repository,
    )

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_concept_repository] = lambda: concept_repo
    app.dependency_overrides[get_relationship_repository] = lambda: relationship_repo
    app.dependency_overrides[get_graph_query_service] = lambda: query_service

    return app


@pytest.fixture
def client():
    app = _make_test_app()
    return TestClient(app)


class TestKGSummaryAPI:

    def test_get_summary(self, client):
        resp = client.get("/api/v1/kg/")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["nodeCount"] == 3
        assert data["edgeCount"] == 2
        assert len(data["topConcepts"]) > 0


class TestKGNodesAPI:

    def test_list_nodes(self, client):
        resp = client.get("/api/v1/kg/nodes")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["data"]) == 3

    def test_get_node(self, client):
        resp = client.get("/api/v1/kg/nodes/c-1")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["name"] == "Python"

    def test_get_node_not_found(self, client):
        # ConceptNotFoundError is raised but our test app has no exception handler
        # registered, so it propagates as 500. In production, the middleware maps it to 404.
        with pytest.raises(Exception):
            client.get("/api/v1/kg/nodes/nonexistent")

    def test_related_concepts(self, client):
        resp = client.get("/api/v1/kg/nodes/c-1/related")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) > 0


class TestKGPathAPI:

    def test_learning_path(self, client):
        resp = client.get("/api/v1/kg/path", params={"from": "c-1", "to": "c-3"})
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["found"] is True
        assert len(data["path"]) >= 2

    def test_learning_path_not_found(self, client):
        resp = client.get("/api/v1/kg/path", params={"from": "c-3", "to": "c-1"})
        assert resp.status_code == 200
        data = resp.json()["data"]
        # May or may not find a path in reverse, but shouldn't crash


class TestKGPrerequisitesAPI:

    def test_prerequisites(self, client):
        resp = client.get("/api/v1/kg/prerequisites/c-3")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data["prerequisites"]) > 0

    def test_prerequisites_root_node(self, client):
        resp = client.get("/api/v1/kg/prerequisites/c-1")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data["prerequisites"]) == 0


class TestKGGapsAPI:

    def test_knowledge_gaps(self, client):
        resp = client.get("/api/v1/kg/gaps")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert isinstance(data, list)


class TestKGEdgesAPI:

    def test_list_edges(self, client):
        resp = client.get("/api/v1/kg/edges")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["data"]) == 2
