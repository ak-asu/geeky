"""ChromaDB vector store — implements VectorStore Protocol.

Uses chromadb-client HTTP client with a single shared collection.
Every operation filters by user_id in metadata for data isolation (SE-03).
"""

from __future__ import annotations

import asyncio
import logging

from app.exceptions import ExternalServiceError
from app.services.vector_store.base import QueryResult

logger = logging.getLogger(__name__)


class ChromaDBStore:
    """Vector store backed by ChromaDB HTTP server.

    Args:
        host: ChromaDB server host.
        port: ChromaDB server port.
        collection_name: Shared collection name (default: geeky_chunks).
    """

    def __init__(
        self,
        host: str = "localhost",
        port: int = 8001,
        collection_name: str = "geeky_chunks",
        timeout_seconds: float = 10.0,
    ) -> None:
        import chromadb  # noqa: PLC0415

        self._client = chromadb.HttpClient(host=host, port=port)
        self._collection_name = collection_name
        self._timeout = timeout_seconds
        self._collection = self._client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"},
        )

    async def add(
        self,
        ids: list[str],
        embeddings: list[list[float]],
        documents: list[str],
        metadatas: list[dict],
        user_id: str,
    ) -> None:
        """Add vectors with user_id injected into metadata."""
        enriched = [{**m, "user_id": user_id} for m in metadatas]
        try:
            await asyncio.wait_for(
                asyncio.to_thread(
                    self._collection.add,
                    ids=ids,
                    embeddings=embeddings,
                    documents=documents,
                    metadatas=enriched,
                ),
                timeout=self._timeout,
            )
        except asyncio.TimeoutError:
            logger.error("ChromaDB add timed out after %.1fs", self._timeout)
            raise ExternalServiceError("ChromaDB", f"Add timed out after {self._timeout}s")
        except Exception as exc:
            logger.error("ChromaDB add failed: %s", exc)
            raise ExternalServiceError("ChromaDB", str(exc)) from exc

    async def query(
        self,
        embedding: list[float],
        user_id: str,
        n_results: int = 10,
        where: dict | None = None,
    ) -> QueryResult:
        """Query vectors filtered by user_id. Returns empty result on timeout."""
        user_filter = {"user_id": user_id}
        if where:
            combined = {"$and": [user_filter, where]}
        else:
            combined = user_filter

        try:
            result = await asyncio.wait_for(
                asyncio.to_thread(
                    self._collection.query,
                    query_embeddings=[embedding],
                    n_results=n_results,
                    where=combined,
                    include=["documents", "metadatas", "distances"],
                ),
                timeout=self._timeout,
            )
            return QueryResult(
                ids=result["ids"][0] if result["ids"] else [],
                documents=result["documents"][0] if result["documents"] else [],
                metadatas=result["metadatas"][0] if result["metadatas"] else [],
                distances=result["distances"][0] if result["distances"] else [],
            )
        except asyncio.TimeoutError:
            logger.warning("ChromaDB query timed out after %.1fs — returning empty results", self._timeout)
            return QueryResult(ids=[], documents=[], metadatas=[], distances=[])
        except Exception as exc:
            logger.error("ChromaDB query failed: %s", exc)
            raise ExternalServiceError("ChromaDB", str(exc)) from exc

    async def delete(self, ids: list[str], user_id: str) -> None:
        """Delete vectors by IDs, scoped to user_id."""
        if not ids:
            return
        try:
            await asyncio.to_thread(
                self._collection.delete,
                ids=ids,
                where={"user_id": user_id},
            )
        except Exception as exc:
            logger.error("ChromaDB delete failed: %s", exc)
            raise ExternalServiceError("ChromaDB", str(exc)) from exc

    async def get(self, ids: list[str], user_id: str) -> QueryResult:
        """Get vectors by IDs, scoped to user_id."""
        if not ids:
            return QueryResult(ids=[], documents=[], metadatas=[], distances=[])
        try:
            result = await asyncio.to_thread(
                self._collection.get,
                ids=ids,
                where={"user_id": user_id},
                include=["documents", "metadatas"],
            )
            return QueryResult(
                ids=result["ids"] or [],
                documents=result["documents"] or [],
                metadatas=result["metadatas"] or [],
                distances=[0.0] * len(result["ids"] or []),
            )
        except Exception as exc:
            logger.error("ChromaDB get failed: %s", exc)
            raise ExternalServiceError("ChromaDB", str(exc)) from exc

    async def count(self, user_id: str) -> int:
        """Count vectors belonging to a user."""
        try:
            result = await asyncio.to_thread(
                self._collection.get,
                where={"user_id": user_id},
                include=[],
            )
            return len(result["ids"] or [])
        except Exception as exc:
            logger.error("ChromaDB count failed: %s", exc)
            raise ExternalServiceError("ChromaDB", str(exc)) from exc
