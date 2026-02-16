"""Unit tests for HybridSearchService."""

from __future__ import annotations

from dataclasses import dataclass
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.search.base import SparseResult
from app.services.search.hybrid_search import HybridSearchService
from app.services.vector_store.base import QueryResult


@dataclass
class _MockShort:
    id: str
    title: str
    content: str
    summary: str
    topics: list


def _make_settings(**overrides):
    """Create a mock settings object."""
    defaults = {
        "search_rrf_k": 60,
        "search_default_limit": 20,
        "rag_top_k": 10,
    }
    defaults.update(overrides)
    settings = MagicMock()
    for k, v in defaults.items():
        setattr(settings, k, v)
    return settings


@pytest.fixture
def mock_sparse():
    engine = MagicMock()
    engine.index = MagicMock()
    engine.search = MagicMock(return_value=[
        SparseResult(document_id="short1", score=2.5),
        SparseResult(document_id="short2", score=1.8),
        SparseResult(document_id="short3", score=1.0),
    ])
    return engine


@pytest.fixture
def mock_vector_store():
    store = AsyncMock()
    store.query = AsyncMock(return_value=QueryResult(
        ids=["chunk1", "chunk2", "chunk3"],
        documents=["doc1 content", "doc2 content", "doc3 content"],
        metadatas=[
            {"short_id": "short2", "user_id": "user1"},
            {"short_id": "short1", "user_id": "user1"},
            {"short_id": "short4", "user_id": "user1"},
        ],
        distances=[0.1, 0.2, 0.3],
    ))
    return store


@pytest.fixture
def mock_embedder():
    embedder = AsyncMock()
    embedder.embed_query = AsyncMock(return_value=[0.1] * 768)
    return embedder


@pytest.fixture
def mock_short_repo():
    shorts = {
        "short1": _MockShort("short1", "ML Basics", "Machine learning intro", "ML intro", ["ml"]),
        "short2": _MockShort("short2", "Python Tips", "Python programming", "Python tips", ["python"]),
        "short3": _MockShort("short3", "Deep Learning", "Neural networks", "DL intro", ["ml", "dl"]),
        "short4": _MockShort("short4", "Data Science", "Data analysis", "DS intro", ["data"]),
    }

    repo = AsyncMock()
    repo.query = AsyncMock(return_value=list(shorts.values()))
    repo.get = AsyncMock(side_effect=lambda uid, sid: shorts.get(sid))
    return repo


@pytest.fixture
def service(mock_sparse, mock_vector_store, mock_embedder, mock_short_repo):
    return HybridSearchService(
        sparse_engine=mock_sparse,
        vector_store=mock_vector_store,
        embedding_provider=mock_embedder,
        short_repo=mock_short_repo,
        settings=_make_settings(),
    )


class TestSearch:
    @pytest.mark.asyncio
    async def test_returns_results(self, service):
        results = await service.search("user1", "machine learning", top_k=5)
        assert len(results) > 0

    @pytest.mark.asyncio
    async def test_empty_query_returns_empty(self, service):
        results = await service.search("user1", "")
        assert results == []

    @pytest.mark.asyncio
    async def test_results_have_required_fields(self, service):
        results = await service.search("user1", "python", top_k=5)
        for r in results:
            assert r.short_id
            assert r.title
            assert r.score > 0

    @pytest.mark.asyncio
    async def test_topic_filtering(self, service):
        results = await service.search("user1", "learning", top_k=5, topic="ml")
        for r in results:
            assert "ml" in [t.lower() for t in r.topics]

    @pytest.mark.asyncio
    async def test_builds_sparse_index_on_first_search(self, service, mock_sparse, mock_short_repo):
        await service.search("user1", "test")
        mock_short_repo.query.assert_called_once()
        mock_sparse.index.assert_called_once()

    @pytest.mark.asyncio
    async def test_caches_sparse_index(self, service, mock_short_repo):
        await service.search("user1", "test1")
        await service.search("user1", "test2")
        # Should only build index once
        assert mock_short_repo.query.call_count == 1


class TestRRFFusion:
    def test_rrf_merges_rankings(self, service):
        sparse = [("doc1", 0), ("doc2", 1), ("doc3", 2)]
        dense = [("doc2", 0), ("doc3", 1), ("doc4", 2)]

        fused = service._reciprocal_rank_fusion(sparse, dense)
        ids = [doc_id for doc_id, _ in fused]

        # doc2 appears in both lists → should rank highest
        assert ids[0] == "doc2"
        # All 4 unique docs should appear
        assert len(fused) == 4

    def test_rrf_with_empty_lists(self, service):
        fused = service._reciprocal_rank_fusion([], [])
        assert fused == []


class TestInvalidation:
    @pytest.mark.asyncio
    async def test_invalidate_forces_reindex(self, service, mock_short_repo):
        await service.search("user1", "test")
        service.invalidate_user_index("user1")
        await service.search("user1", "test2")
        # Should have queried the repo twice
        assert mock_short_repo.query.call_count == 2
