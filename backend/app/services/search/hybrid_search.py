"""Hybrid search service — combines sparse (BM25) + dense (vector) search.

Uses Reciprocal Rank Fusion (RRF) to merge results from both retrieval
paths. All queries are user_id scoped for data isolation (SE-03).
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

from app.config import Settings
from app.models.rag import SearchResultItem
from app.services.search.base import SparseSearchEngine

logger = logging.getLogger(__name__)


class HybridSearchService:
    """Orchestrates sparse + dense search with RRF fusion.

    Args:
        sparse_engine: BM25-based sparse search.
        vector_store: ChromaDB vector store (VectorStore Protocol).
        embedding_provider: Embedding model (EmbeddingProvider Protocol).
        short_repo: Repository for Short documents.
        settings: Application settings.
    """

    def __init__(
        self,
        *,
        sparse_engine: SparseSearchEngine,
        vector_store: Any,  # VectorStore Protocol
        embedding_provider: Any,  # EmbeddingProvider Protocol
        short_repo: Any,  # ShortRepository
        settings: Settings,
    ) -> None:
        self._sparse = sparse_engine
        self._vector_store = vector_store
        self._embedder = embedding_provider
        self._short_repo = short_repo
        self._settings = settings
        # Per-user BM25 index state
        self._indexed_users: set[str] = set()

    async def _ensure_sparse_index(self, user_id: str) -> None:
        """Lazily build the BM25 index for a user's shorts."""
        if user_id in self._indexed_users:
            return

        shorts = await self._short_repo.query(user_id, limit=5000)
        if not shorts:
            self._indexed_users.add(user_id)
            return

        corpus = [f"{s.title} {s.content}" for s in shorts]
        ids = [s.id for s in shorts]

        await asyncio.to_thread(self._sparse.index, corpus, ids)
        self._indexed_users.add(user_id)
        logger.info("Built sparse index for user %s with %d shorts", user_id, len(shorts))

    def invalidate_user_index(self, user_id: str) -> None:
        """Invalidate the sparse index for a user (call after CRUD on shorts)."""
        self._indexed_users.discard(user_id)

    async def search(
        self,
        user_id: str,
        query: str,
        *,
        top_k: int = 20,
        topic: str | None = None,
        module_id: str | None = None,
    ) -> list[SearchResultItem]:
        """Run hybrid search: sparse + dense → RRF fusion → return ranked results."""
        if not query.strip():
            return []

        # Ensure BM25 index is built
        await self._ensure_sparse_index(user_id)

        retrieval_k = top_k * 3  # Over-retrieve for fusion

        # Run sparse and dense searches in parallel
        sparse_task = asyncio.create_task(self._sparse_search(query, retrieval_k))
        dense_task = asyncio.create_task(
            self._dense_search(user_id, query, retrieval_k, topic=topic)
        )

        sparse_results, dense_results = await asyncio.gather(sparse_task, dense_task)

        # RRF fusion
        fused = self._reciprocal_rank_fusion(sparse_results, dense_results)

        # Collect unique short IDs in ranked order
        ranked_ids = [doc_id for doc_id, _ in fused[:top_k]]
        if not ranked_ids:
            return []

        # Fetch short metadata
        shorts_map = await self._fetch_shorts(user_id, ranked_ids)

        # Build response
        results = []
        for doc_id, score in fused[:top_k]:
            short = shorts_map.get(doc_id)
            if short is None:
                continue

            # Apply topic filter if specified
            if topic and topic.lower() not in [t.lower() for t in short.topics]:
                continue

            snippet = short.summary or short.content[:200]
            results.append(
                SearchResultItem(
                    short_id=short.id,
                    title=short.title,
                    snippet=snippet,
                    score=score,
                    topics=short.topics,
                )
            )

        return results

    async def _sparse_search(
        self, query: str, top_k: int
    ) -> list[tuple[str, int]]:
        """Run BM25 search, return (doc_id, rank) pairs."""
        sparse_results = await asyncio.to_thread(self._sparse.search, query, top_k)
        return [(r.document_id, rank) for rank, r in enumerate(sparse_results)]

    async def _dense_search(
        self,
        user_id: str,
        query: str,
        top_k: int,
        *,
        topic: str | None = None,
    ) -> list[tuple[str, int]]:
        """Run vector search, return (doc_id, rank) pairs."""
        query_embedding = await self._embedder.embed_query(query)

        where = None
        if topic:
            where = {"topic": topic}

        result = await self._vector_store.query(
            embedding=query_embedding,
            user_id=user_id,
            n_results=top_k,
            where=where,
        )

        # ChromaDB returns chunk IDs; extract short_id from metadata
        ranked = []
        seen = set()
        for rank, (doc_id, meta) in enumerate(zip(result.ids, result.metadatas)):
            short_id = meta.get("short_id", doc_id) if meta else doc_id
            if short_id not in seen:
                seen.add(short_id)
                ranked.append((short_id, rank))

        return ranked

    def _reciprocal_rank_fusion(
        self,
        sparse_ranks: list[tuple[str, int]],
        dense_ranks: list[tuple[str, int]],
    ) -> list[tuple[str, float]]:
        """Merge two ranked lists using Reciprocal Rank Fusion (RRF).

        RRF score = sum(1 / (k + rank)) across all lists.
        """
        k = self._settings.search_rrf_k
        scores: dict[str, float] = {}

        for doc_id, rank in sparse_ranks:
            scores[doc_id] = scores.get(doc_id, 0.0) + 1.0 / (k + rank)

        for doc_id, rank in dense_ranks:
            scores[doc_id] = scores.get(doc_id, 0.0) + 1.0 / (k + rank)

        # Sort by fused score descending
        fused = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        return fused

    async def _fetch_shorts(
        self, user_id: str, short_ids: list[str]
    ) -> dict[str, Any]:
        """Fetch shorts by ID and return a mapping."""
        shorts_map = {}
        for short_id in short_ids:
            short = await self._short_repo.get(user_id, short_id)
            if short:
                shorts_map[short_id] = short
        return shorts_map
