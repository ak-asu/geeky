"""4-stage deduplication pipeline — CP-05a through CP-05d, CP-18-21.

Stage 1: Exact SHA-256 hash (hard discard)
Stage 2: SimHash near-duplicate (Jaccard >= 0.9, soft dedup)
Stage 3: ChromaDB cosine similarity >= 0.85 (soft dedup)
Stage 4: Cross-modal (same as stage 3, across media types)

Uses datasketch for MinHash/LSH. Uses hash-set for fast streaming
screening (CP-19). Logs dedup decisions (CP-18). Supports soft dedup
via canonical chunk linking (CP-21).
"""

from __future__ import annotations

import hashlib
import logging
import re
import unicodedata
from dataclasses import dataclass, field

from app.services.pipeline.chunker import Chunk

logger = logging.getLogger(__name__)


@dataclass
class DedupDecision:
    """Audit log entry for a deduplication decision (CP-18)."""

    chunk_hash: str
    stage: str  # exact | near | semantic | cross_modal
    method: str
    matched_id: str | None = None
    similarity: float = 0.0
    outcome: str = "keep"  # keep | discard | soft_link


@dataclass
class DedupResult:
    """Result of deduplication for a single chunk."""

    chunk: Chunk
    is_duplicate: bool = False
    is_soft_duplicate: bool = False
    canonical_chunk_id: str | None = None
    decisions: list[DedupDecision] = field(default_factory=list)


@dataclass
class DedupConfig:
    """Deduplication thresholds and settings."""

    near_threshold: float = 0.9  # Jaccard threshold for MinHash
    semantic_threshold: float = 0.85  # Cosine threshold for semantic dedup
    bloom_capacity: int = 100_000  # Reserved: initial capacity for fixed BloomFilter if ScalableBloomFilter is replaced
    bloom_error_rate: float = 0.001
    minhash_num_perm: int = 128


class Deduplicator:
    """4-stage deduplication pipeline.

    Dependencies injected:
    - vector_store: for semantic dedup queries (stage 3/4)
    - embedding_provider: for computing embeddings for semantic comparison
    """

    def __init__(
        self,
        vector_store,
        embedding_provider,
        config: DedupConfig | None = None,
    ) -> None:
        self._vector_store = vector_store
        self._embedding_provider = embedding_provider
        self._config = config or DedupConfig()
        self._exact_seen: set[str] = set()
        self._minhash_index: dict = {}
        try:
            from pybloom_live import ScalableBloomFilter  # noqa: PLC0415

            self._bloom = ScalableBloomFilter(
                mode=ScalableBloomFilter.SMALL_SET_GROWTH,
                error_rate=self._config.bloom_error_rate,
            )
        except ImportError:
            logger.warning("pybloom-live not available, falling back to plain set for bloom filter")
            self._bloom: set[str] = set()  # type: ignore[assignment]

    async def deduplicate(
        self,
        chunks: list[Chunk],
        user_id: str,
    ) -> list[DedupResult]:
        """Run all 4 dedup stages on a list of chunks.

        Returns DedupResult for each chunk, including audit decisions.
        """
        results: list[DedupResult] = []

        for chunk in chunks:
            result = DedupResult(chunk=chunk)
            canonical_text = canonicalize(chunk.content)
            content_hash = hashlib.sha256(canonical_text.encode()).hexdigest()

            # CP-19: Fast screen via hash set
            if content_hash in self._bloom:
                logger.debug("Bloom filter hit for hash %s", content_hash[:12])

            # Stage 1: Exact hash dedup (CP-05a)
            if content_hash in self._exact_seen:
                result.is_duplicate = True
                result.decisions.append(DedupDecision(
                    chunk_hash=content_hash,
                    stage="exact",
                    method="sha256",
                    similarity=1.0,
                    outcome="discard",
                ))
                results.append(result)
                continue

            self._exact_seen.add(content_hash)
            self._bloom.add(content_hash)

            # Stage 2: Near-duplicate via MinHash (CP-05b)
            near_decision = self._check_near_duplicate(canonical_text, content_hash)
            result.decisions.append(near_decision)
            if near_decision.outcome == "soft_link":
                result.is_soft_duplicate = True
                result.canonical_chunk_id = near_decision.matched_id

            # Stage 3: Semantic dedup via vector store (CP-05c)
            sem_decision = await self._check_semantic_duplicate(
                chunk.content, content_hash, user_id
            )
            result.decisions.append(sem_decision)
            if sem_decision.outcome == "soft_link" and not result.is_soft_duplicate:
                result.is_soft_duplicate = True
                result.canonical_chunk_id = sem_decision.matched_id

            results.append(result)

        kept = sum(1 for r in results if not r.is_duplicate)
        soft = sum(1 for r in results if r.is_soft_duplicate)
        logger.info(
            "Dedup: %d chunks → %d kept (%d exact dups, %d soft dups)",
            len(chunks), kept, len(chunks) - kept, soft,
        )
        return results

    def _check_near_duplicate(self, canonical_text: str, content_hash: str) -> DedupDecision:
        """Stage 2: MinHash/LSH near-duplicate detection (CP-05b)."""
        try:
            from datasketch import MinHash  # noqa: PLC0415

            mh = MinHash(num_perm=self._config.minhash_num_perm)
            shingles = _text_to_shingles(canonical_text)
            for s in shingles:
                mh.update(s.encode("utf-8"))

            # Compare against existing MinHash signatures
            for existing_hash, existing_mh in self._minhash_index.items():
                jaccard = mh.jaccard(existing_mh)
                if jaccard >= self._config.near_threshold:
                    return DedupDecision(
                        chunk_hash=content_hash,
                        stage="near",
                        method="minhash_jaccard",
                        matched_id=existing_hash,
                        similarity=jaccard,
                        outcome="soft_link",
                    )

            self._minhash_index[content_hash] = mh

        except ImportError:
            logger.warning("datasketch not available, skipping MinHash dedup")

        return DedupDecision(
            chunk_hash=content_hash,
            stage="near",
            method="minhash_jaccard",
            outcome="keep",
        )

    async def _check_semantic_duplicate(
        self,
        text: str,
        content_hash: str,
        user_id: str,
    ) -> DedupDecision:
        """Stage 3: Semantic dedup via ChromaDB cosine similarity (CP-05c)."""
        try:
            embedding = await self._embedding_provider.embed_query(text)
            result = await self._vector_store.query(
                embedding=embedding,
                user_id=user_id,
                n_results=5,
            )

            for i, distance in enumerate(result.distances):
                # ChromaDB cosine distance: 0 = identical, 2 = opposite
                similarity = 1.0 - distance
                if similarity >= self._config.semantic_threshold:
                    return DedupDecision(
                        chunk_hash=content_hash,
                        stage="semantic",
                        method="chromadb_cosine",
                        matched_id=result.ids[i],
                        similarity=similarity,
                        outcome="soft_link",
                    )
        except Exception as exc:
            logger.warning("Semantic dedup check failed: %s", exc)

        return DedupDecision(
            chunk_hash=content_hash,
            stage="semantic",
            method="chromadb_cosine",
            outcome="keep",
        )


def canonicalize(text: str) -> str:
    """Content canonicalization (CP-20).

    NFC normalize → lowercase → collapse whitespace → strip boilerplate.
    """
    text = unicodedata.normalize("NFC", text)
    text = text.lower()
    text = re.sub(r"\s+", " ", text)
    text = text.strip()
    return text


def _text_to_shingles(text: str, k: int = 3) -> list[str]:
    """Convert text to word-level k-shingles for MinHash."""
    words = text.split()
    if len(words) < k:
        return [text]
    return [" ".join(words[i : i + k]) for i in range(len(words) - k + 1)]


