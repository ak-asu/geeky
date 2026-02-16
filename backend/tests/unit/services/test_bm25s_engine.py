"""Unit tests for BM25SSearchEngine."""

from __future__ import annotations

import pytest

from app.services.search.bm25s_engine import BM25SSearchEngine


@pytest.fixture
def engine():
    return BM25SSearchEngine()


@pytest.fixture
def indexed_engine():
    engine = BM25SSearchEngine()
    corpus = [
        "Machine learning is a subset of artificial intelligence",
        "Python is a popular programming language",
        "Neural networks are used in deep learning",
        "Data structures and algorithms are fundamental in computer science",
        "Natural language processing handles text data",
    ]
    ids = ["doc1", "doc2", "doc3", "doc4", "doc5"]
    engine.index(corpus, ids)
    return engine


class TestIndex:
    def test_index_sets_corpus(self, engine):
        engine.index(["hello world"], ["id1"])
        assert engine.size == 1

    def test_index_replaces_existing(self, engine):
        engine.index(["first"], ["id1"])
        engine.index(["second", "third"], ["id2", "id3"])
        assert engine.size == 2

    def test_index_mismatched_lengths_raises(self, engine):
        with pytest.raises(ValueError, match="corpus length"):
            engine.index(["one", "two"], ["id1"])

    def test_empty_index(self, engine):
        engine.index([], [])
        assert engine.size == 0


class TestSearch:
    def test_search_returns_relevant_results(self, indexed_engine):
        results = indexed_engine.search("machine learning artificial intelligence")
        assert len(results) > 0
        assert results[0].document_id == "doc1"

    def test_search_with_top_k(self, indexed_engine):
        results = indexed_engine.search("learning", top_k=2)
        assert len(results) <= 2

    def test_search_empty_query(self, indexed_engine):
        results = indexed_engine.search("")
        assert results == []

    def test_search_no_match(self, indexed_engine):
        results = indexed_engine.search("xyznonexistent")
        assert results == []

    def test_search_empty_index(self, engine):
        results = engine.search("hello")
        assert results == []

    def test_scores_are_positive(self, indexed_engine):
        results = indexed_engine.search("python programming")
        for r in results:
            assert r.score > 0

    def test_results_sorted_by_score(self, indexed_engine):
        results = indexed_engine.search("learning")
        scores = [r.score for r in results]
        assert scores == sorted(scores, reverse=True)


class TestAdd:
    def test_add_new_documents(self, indexed_engine):
        original_size = indexed_engine.size
        indexed_engine.add(["New document about testing"], ["doc6"])
        assert indexed_engine.size == original_size + 1

    def test_add_updates_existing(self, indexed_engine):
        original_size = indexed_engine.size
        indexed_engine.add(["Updated content for doc1"], ["doc1"])
        assert indexed_engine.size == original_size  # No new doc added


class TestRemove:
    def test_remove_documents(self, indexed_engine):
        indexed_engine.remove(["doc1"])
        assert indexed_engine.size == 4
        results = indexed_engine.search("machine learning artificial intelligence")
        ids = [r.document_id for r in results]
        assert "doc1" not in ids

    def test_remove_nonexistent(self, indexed_engine):
        original_size = indexed_engine.size
        indexed_engine.remove(["nonexistent"])
        assert indexed_engine.size == original_size

    def test_remove_all(self, indexed_engine):
        indexed_engine.remove(["doc1", "doc2", "doc3", "doc4", "doc5"])
        assert indexed_engine.size == 0
        assert indexed_engine.search("anything") == []
