"""Unit tests for CrossEncoderReranker."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import numpy as np
import pytest

from app.services.rag.reranker.cross_encoder import CrossEncoderReranker


@pytest.fixture
def reranker():
    """Create a reranker with mocked model."""
    r = CrossEncoderReranker()
    mock_model = MagicMock()
    mock_model.predict = MagicMock(return_value=np.array([0.9, 0.3, 0.7, 0.1]))
    r._model = mock_model
    return r


class TestRerank:
    @pytest.mark.asyncio
    async def test_reranks_by_score(self, reranker):
        results = await reranker.rerank(
            query="What is machine learning?",
            documents=["ML is AI", "Python code", "Deep learning", "Cooking recipe"],
            document_ids=["d1", "d2", "d3", "d4"],
            top_k=4,
        )
        assert len(results) == 4
        # Highest score first
        assert results[0].document_id == "d1"
        assert results[0].score == pytest.approx(0.9)
        assert results[1].document_id == "d3"

    @pytest.mark.asyncio
    async def test_top_k_limits_results(self, reranker):
        results = await reranker.rerank(
            query="test",
            documents=["a", "b", "c", "d"],
            document_ids=["1", "2", "3", "4"],
            top_k=2,
        )
        assert len(results) == 2

    @pytest.mark.asyncio
    async def test_empty_documents(self, reranker):
        results = await reranker.rerank(
            query="test",
            documents=[],
            document_ids=[],
            top_k=5,
        )
        assert results == []

    @pytest.mark.asyncio
    async def test_mismatched_lengths_raises(self, reranker):
        with pytest.raises(ValueError, match="documents"):
            await reranker.rerank(
                query="test",
                documents=["a", "b"],
                document_ids=["1"],
                top_k=2,
            )

    @pytest.mark.asyncio
    async def test_preserves_content(self, reranker):
        results = await reranker.rerank(
            query="test",
            documents=["content A", "content B", "content C", "content D"],
            document_ids=["1", "2", "3", "4"],
            top_k=4,
        )
        contents = {r.document_id: r.content for r in results}
        assert contents["1"] == "content A"
        assert contents["2"] == "content B"
