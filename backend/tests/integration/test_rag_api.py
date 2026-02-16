"""Integration tests for RAG API routes."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.rag import router
from app.models.rag import RAGCitation, RAGQueryRequest, RAGQueryResponse


# ---- Mock RAG orchestrator ----


class MockRAGOrchestrator:
    async def query(self, user_id, request: RAGQueryRequest):
        return RAGQueryResponse(
            answer="Machine learning is a subset of AI that enables systems to learn from data.",
            citations=[
                RAGCitation(short_id="s1", title="ML Basics", snippet="ML is a subset of AI"),
                RAGCitation(short_id="s2", title="AI Overview", snippet="AI encompasses ML"),
            ],
            follow_up_questions=["What are the types of ML?", "How does deep learning differ?"],
        )


# ---- App setup ----


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.dependencies import get_rag_orchestrator

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_rag_orchestrator] = lambda: MockRAGOrchestrator()

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestRAGQuery:
    def test_qa_mode(self, client):
        resp = client.post("/api/v1/rag/query", json={
            "question": "What is machine learning?",
        })
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["answer"]
        assert len(data["citations"]) == 2

    def test_study_guide_mode(self, client):
        resp = client.post("/api/v1/rag/query", json={
            "question": "Study guide for ML",
            "mode": "study_guide",
        })
        assert resp.status_code == 200

    def test_response_has_citations(self, client):
        resp = client.post("/api/v1/rag/query", json={"question": "test"})
        citations = resp.json()["data"]["citations"]
        assert len(citations) > 0
        assert "shortId" in citations[0]
        assert "title" in citations[0]

    def test_response_has_follow_ups(self, client):
        resp = client.post("/api/v1/rag/query", json={"question": "test"})
        data = resp.json()["data"]
        assert "followUpQuestions" in data

    def test_missing_question_fails(self, client):
        resp = client.post("/api/v1/rag/query", json={})
        assert resp.status_code == 422
