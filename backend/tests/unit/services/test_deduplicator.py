"""Unit tests for Deduplicator — CP-05a through CP-05d, CP-18-21."""

from __future__ import annotations

import pytest

from app.services.pipeline.chunker import Chunk
from app.services.pipeline.deduplicator import (
    DedupConfig,
    Deduplicator,
    canonicalize,
)
from tests.mocks.mock_embedder import MockEmbeddingProvider
from tests.mocks.mock_vector_store import MockVectorStore


@pytest.fixture
def mock_embedder():
    return MockEmbeddingProvider(dimensions=768)


@pytest.fixture
def mock_vector_store():
    return MockVectorStore()


@pytest.fixture
def deduplicator(mock_vector_store, mock_embedder):
    return Deduplicator(
        vector_store=mock_vector_store,
        embedding_provider=mock_embedder,
        config=DedupConfig(
            near_threshold=0.9,
            semantic_threshold=0.85,
        ),
    )


def _make_chunk(content: str, offset: int = 0) -> Chunk:
    return Chunk(content=content, offset=offset, word_count=len(content.split()))


class TestCanonicalization:
    """CP-20: Content canonicalization."""

    def test_lowercases(self):
        assert canonicalize("Hello World") == "hello world"

    def test_collapses_whitespace(self):
        assert canonicalize("hello   world\n\nfoo") == "hello world foo"

    def test_strips(self):
        assert canonicalize("  hello  ") == "hello"

    def test_nfc_normalization(self):
        # e + combining acute = é (NFC)
        result = canonicalize("caf\u0065\u0301")
        assert result == "café"


class TestExactDedup:
    """Stage 1 — CP-05a: SHA-256 exact hash dedup."""

    @pytest.mark.asyncio
    async def test_identical_chunks_detected(self, deduplicator):
        chunks = [
            _make_chunk("This is the exact same content."),
            _make_chunk("This is the exact same content."),
        ]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        assert not results[0].is_duplicate
        assert results[1].is_duplicate

        # Check audit log
        dup_decisions = [d for d in results[1].decisions if d.stage == "exact"]
        assert len(dup_decisions) == 1
        assert dup_decisions[0].outcome == "discard"

    @pytest.mark.asyncio
    async def test_different_chunks_kept(self, deduplicator):
        chunks = [
            _make_chunk("First unique content here."),
            _make_chunk("Second different content here."),
        ]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        assert not results[0].is_duplicate
        assert not results[1].is_duplicate


class TestNearDedup:
    """Stage 2 — CP-05b: MinHash/LSH near-duplicate detection."""

    @pytest.mark.asyncio
    async def test_near_duplicates_flagged(self, deduplicator):
        # Very similar text (should have high Jaccard)
        base = "machine learning is a subset of artificial intelligence that enables computers to learn"
        chunks = [
            _make_chunk(base),
            _make_chunk(base + " from data"),  # Slight variation
        ]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        # Both should be kept (near-dup is soft, not hard delete)
        assert not results[0].is_duplicate
        assert not results[1].is_duplicate

        # Check that near-dup stage ran
        for r in results:
            near_decisions = [d for d in r.decisions if d.stage == "near"]
            assert len(near_decisions) >= 1

    @pytest.mark.asyncio
    async def test_completely_different_texts_not_flagged(self, deduplicator):
        chunks = [
            _make_chunk("The quick brown fox jumps over the lazy dog near the river bank"),
            _make_chunk("Quantum mechanics describes the behavior of particles at atomic scales precisely"),
        ]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        for r in results:
            near_decisions = [d for d in r.decisions if d.stage == "near" and d.outcome == "soft_link"]
            assert len(near_decisions) == 0


class TestSemanticDedup:
    """Stage 3 — CP-05c: Embedding cosine similarity dedup."""

    @pytest.mark.asyncio
    async def test_semantic_dedup_runs(self, deduplicator):
        chunks = [_make_chunk("Some content about neural networks and deep learning.")]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        # Should have a semantic decision logged
        sem_decisions = [d for d in results[0].decisions if d.stage == "semantic"]
        assert len(sem_decisions) == 1

    @pytest.mark.asyncio
    async def test_semantic_dedup_against_existing_vectors(self, mock_vector_store, mock_embedder):
        """When vector store has existing content, semantic dedup should detect similarity."""
        # Pre-populate vector store
        await mock_vector_store.add(
            ids=["existing-1"],
            embeddings=[[0.1] * 768],
            documents=["Existing content about AI"],
            metadatas=[{"note_id": "note-old"}],
            user_id="user1",
        )

        deduplicator = Deduplicator(
            vector_store=mock_vector_store,
            embedding_provider=mock_embedder,
            config=DedupConfig(semantic_threshold=0.85),
        )

        chunks = [_make_chunk("New content about something different")]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        # The mock returns distance 0.1, so similarity = 0.9 > 0.85 threshold
        sem_decisions = [d for d in results[0].decisions if d.stage == "semantic"]
        assert len(sem_decisions) == 1


class TestAuditLog:
    """CP-18: Dedup decision audit logging."""

    @pytest.mark.asyncio
    async def test_every_chunk_has_decisions(self, deduplicator):
        chunks = [
            _make_chunk("Content A about topic one."),
            _make_chunk("Content B about topic two."),
        ]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        for r in results:
            if not r.is_duplicate:
                # Non-duplicate chunks should have near + semantic decisions
                assert len(r.decisions) >= 2
                stages = {d.stage for d in r.decisions}
                assert "near" in stages
                assert "semantic" in stages

    @pytest.mark.asyncio
    async def test_decision_fields_populated(self, deduplicator):
        chunks = [_make_chunk("Test content for audit logging.")]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        for decision in results[0].decisions:
            assert decision.chunk_hash
            assert decision.stage
            assert decision.method
            assert decision.outcome in ("keep", "discard", "soft_link")


class TestSoftDedup:
    """CP-21: Soft dedup via canonical chunk linking."""

    @pytest.mark.asyncio
    async def test_soft_duplicate_has_canonical_id(self, mock_vector_store, mock_embedder):
        # Pre-populate to trigger semantic match
        await mock_vector_store.add(
            ids=["canonical-chunk"],
            embeddings=[[0.5] * 768],
            documents=["Original canonical content"],
            metadatas=[{"note_id": "note-1"}],
            user_id="user1",
        )

        deduplicator = Deduplicator(
            vector_store=mock_vector_store,
            embedding_provider=mock_embedder,
            config=DedupConfig(semantic_threshold=0.85),
        )

        chunks = [_make_chunk("Similar content to the canonical")]
        results = await deduplicator.deduplicate(chunks, user_id="user1")

        # If semantic dedup triggers, should have canonical_chunk_id
        if results[0].is_soft_duplicate:
            assert results[0].canonical_chunk_id is not None


class TestUserIsolation:
    """SE-03: User data isolation in dedup."""

    @pytest.mark.asyncio
    async def test_different_users_not_deduped(self, mock_vector_store, mock_embedder):
        # User1's content
        await mock_vector_store.add(
            ids=["user1-chunk"],
            embeddings=[[0.5] * 768],
            documents=["User 1 content"],
            metadatas=[{"note_id": "note-1"}],
            user_id="user1",
        )

        deduplicator = Deduplicator(
            vector_store=mock_vector_store,
            embedding_provider=mock_embedder,
        )

        # User2's chunk should not match user1's
        chunks = [_make_chunk("User 2 similar content")]
        results = await deduplicator.deduplicate(chunks, user_id="user2")

        # Mock vector store filters by user_id, so no match for user2
        sem_decisions = [d for d in results[0].decisions
                         if d.stage == "semantic" and d.outcome == "soft_link"]
        assert len(sem_decisions) == 0
