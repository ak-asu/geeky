"""Mock vector store for testing."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class QueryResult:
    ids: list[str] = field(default_factory=list)
    documents: list[str] = field(default_factory=list)
    metadatas: list[dict] = field(default_factory=list)
    distances: list[float] = field(default_factory=list)


class MockVectorStore:
    """In-memory vector store for testing."""

    def __init__(self) -> None:
        self._store: dict[str, dict] = {}

    async def add(
        self,
        ids: list[str],
        embeddings: list[list[float]],
        documents: list[str],
        metadatas: list[dict],
        user_id: str,
    ) -> None:
        for i, doc_id in enumerate(ids):
            self._store[doc_id] = {
                "id": doc_id,
                "embedding": embeddings[i],
                "document": documents[i],
                "metadata": {**metadatas[i], "user_id": user_id},
            }

    async def query(
        self,
        embedding: list[float],
        user_id: str,
        n_results: int = 10,
        where: dict | None = None,
    ) -> QueryResult:
        # Return all user's documents (no real similarity calc in mock)
        user_docs = [
            v for v in self._store.values() if v["metadata"].get("user_id") == user_id
        ][:n_results]

        return QueryResult(
            ids=[d["id"] for d in user_docs],
            documents=[d["document"] for d in user_docs],
            metadatas=[d["metadata"] for d in user_docs],
            distances=[0.1] * len(user_docs),
        )

    async def delete(self, ids: list[str], user_id: str) -> None:
        for doc_id in ids:
            if doc_id in self._store and self._store[doc_id]["metadata"].get("user_id") == user_id:
                del self._store[doc_id]

    async def get(self, ids: list[str], user_id: str) -> QueryResult:
        docs = [
            self._store[doc_id]
            for doc_id in ids
            if doc_id in self._store and self._store[doc_id]["metadata"].get("user_id") == user_id
        ]
        return QueryResult(
            ids=[d["id"] for d in docs],
            documents=[d["document"] for d in docs],
            metadatas=[d["metadata"] for d in docs],
            distances=[0.0] * len(docs),
        )

    async def count(self, user_id: str) -> int:
        return sum(1 for v in self._store.values() if v["metadata"].get("user_id") == user_id)
