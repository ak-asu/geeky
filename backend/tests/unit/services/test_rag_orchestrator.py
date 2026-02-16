"""Unit tests for RAGOrchestrator."""

from __future__ import annotations

from dataclasses import dataclass
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.common import RAGMode
from app.models.rag import RAGQueryRequest
from app.services.rag.rag_orchestrator import RAGOrchestrator, _cosine_similarity, _estimate_tokens
from app.services.rag.reranker.base import RankedDocument


@dataclass
class _MockShort:
    id: str
    title: str
    content: str
    topics: list


def _make_settings(**overrides):
    defaults = {
        "rag_top_k": 5,
        "rag_mmr_lambda": 0.7,
        "rag_context_max_tokens": 4000,
        "rag_redundancy_threshold": 0.92,
        "search_rrf_k": 60,
        "search_default_limit": 20,
    }
    defaults.update(overrides)
    settings = MagicMock()
    for k, v in defaults.items():
        setattr(settings, k, v)
    return settings


@pytest.fixture
def mock_search():
    search = AsyncMock()
    from app.models.rag import SearchResultItem

    search.search = AsyncMock(return_value=[
        SearchResultItem(short_id="s1", title="ML Basics", snippet="...", score=0.9, topics=["ml"]),
        SearchResultItem(short_id="s2", title="Python Intro", snippet="...", score=0.7, topics=["python"]),
        SearchResultItem(short_id="s3", title="DL Networks", snippet="...", score=0.5, topics=["ml"]),
    ])
    return search


@pytest.fixture
def mock_reranker():
    reranker = AsyncMock()
    reranker.rerank = AsyncMock(return_value=[
        RankedDocument(document_id="s1", content="ML content here", score=0.95),
        RankedDocument(document_id="s3", content="DL content here", score=0.8),
        RankedDocument(document_id="s2", content="Python content here", score=0.6),
    ])
    return reranker


@pytest.fixture
def mock_llm():
    llm = AsyncMock()
    llm.generate = AsyncMock(return_value="Machine learning is a subset of AI [1]. It uses neural networks [2].")
    return llm


@pytest.fixture
def mock_embedder():
    embedder = AsyncMock()
    # Return distinct embeddings for diversity check
    embedder.embed_texts = AsyncMock(return_value=[
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0],
    ])
    return embedder


@pytest.fixture
def mock_short_repo():
    shorts = {
        "s1": _MockShort("s1", "ML Basics", "Machine learning is a core AI discipline.", ["ml"]),
        "s2": _MockShort("s2", "Python Intro", "Python is a versatile programming language.", ["python"]),
        "s3": _MockShort("s3", "DL Networks", "Deep learning uses multi-layer neural networks.", ["ml"]),
    }
    repo = AsyncMock()
    repo.get = AsyncMock(side_effect=lambda uid, sid: shorts.get(sid))
    return repo


@pytest.fixture
def orchestrator(mock_search, mock_reranker, mock_llm, mock_embedder, mock_short_repo):
    return RAGOrchestrator(
        search_service=mock_search,
        reranker=mock_reranker,
        llm=mock_llm,
        embedding_provider=mock_embedder,
        short_repo=mock_short_repo,
        settings=_make_settings(),
    )


class TestQuery:
    @pytest.mark.asyncio
    async def test_qa_mode_returns_answer(self, orchestrator):
        request = RAGQueryRequest(question="What is machine learning?")
        response = await orchestrator.query("user1", request)

        assert response.answer
        assert len(response.citations) > 0

    @pytest.mark.asyncio
    async def test_citations_have_required_fields(self, orchestrator):
        request = RAGQueryRequest(question="What is ML?")
        response = await orchestrator.query("user1", request)

        for citation in response.citations:
            assert citation.short_id
            assert citation.title

    @pytest.mark.asyncio
    async def test_no_results_returns_fallback(self, orchestrator, mock_search):
        mock_search.search = AsyncMock(return_value=[])
        request = RAGQueryRequest(question="Unknown topic")
        response = await orchestrator.query("user1", request)

        assert "couldn't find" in response.answer.lower()
        assert response.citations == []

    @pytest.mark.asyncio
    async def test_study_guide_mode(self, orchestrator):
        request = RAGQueryRequest(question="Study guide for ML", mode=RAGMode.STUDY_GUIDE)
        response = await orchestrator.query("user1", request)
        assert response.answer

    @pytest.mark.asyncio
    async def test_mind_map_mode(self, orchestrator, mock_llm):
        mock_llm.generate = AsyncMock(return_value='{"central_topic": "ML", "branches": []}')
        request = RAGQueryRequest(question="Mind map of ML", mode=RAGMode.MIND_MAP)
        response = await orchestrator.query("user1", request)
        assert response.mind_map is not None

    @pytest.mark.asyncio
    async def test_calls_search_then_rerank(self, orchestrator, mock_search, mock_reranker):
        request = RAGQueryRequest(question="test")
        await orchestrator.query("user1", request)

        mock_search.search.assert_called_once()
        mock_reranker.rerank.assert_called_once()


class TestHelpers:
    def test_estimate_tokens(self):
        # 10 words * 1.3 = 13 tokens
        assert _estimate_tokens("one two three four five six seven eight nine ten") == 13

    def test_cosine_similarity_identical(self):
        assert _cosine_similarity([1, 0, 0], [1, 0, 0]) == pytest.approx(1.0)

    def test_cosine_similarity_orthogonal(self):
        assert _cosine_similarity([1, 0, 0], [0, 1, 0]) == pytest.approx(0.0)

    def test_cosine_similarity_zero_vector(self):
        assert _cosine_similarity([0, 0, 0], [1, 0, 0]) == pytest.approx(0.0)


class TestMMRPrune:
    @pytest.mark.asyncio
    async def test_diverse_docs_all_kept(self, orchestrator):
        candidates = [
            {"short_id": "s1", "content": "ML content", "rerank_score": 0.9},
            {"short_id": "s2", "content": "Python content", "rerank_score": 0.7},
            {"short_id": "s3", "content": "DL content", "rerank_score": 0.5},
        ]
        result = await orchestrator._mmr_prune(candidates)
        # All docs have orthogonal embeddings → all should be kept
        assert len(result) == 3

    @pytest.mark.asyncio
    async def test_redundant_docs_pruned(self, orchestrator, mock_embedder):
        # Make embeddings nearly identical → should prune
        mock_embedder.embed_texts = AsyncMock(return_value=[
            [1.0, 0.0, 0.0],
            [0.999, 0.01, 0.0],
            [0.998, 0.02, 0.0],
        ])
        candidates = [
            {"short_id": "s1", "content": "ML content", "rerank_score": 0.9},
            {"short_id": "s2", "content": "ML content similar", "rerank_score": 0.7},
            {"short_id": "s3", "content": "ML content very similar", "rerank_score": 0.5},
        ]
        result = await orchestrator._mmr_prune(candidates)
        # First is always kept, redundant ones should be pruned
        assert len(result) < 3
        assert result[0]["short_id"] == "s1"

    @pytest.mark.asyncio
    async def test_single_candidate_returned(self, orchestrator):
        candidates = [{"short_id": "s1", "content": "Only one", "rerank_score": 0.9}]
        result = await orchestrator._mmr_prune(candidates)
        assert len(result) == 1
