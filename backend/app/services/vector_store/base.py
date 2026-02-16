"""Vector store Protocol — abstracts vector database operations."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Protocol

@dataclass
class QueryResult:
    ids: list[str]
    documents: list[str]
    metadatas: list[dict]
    distances: list[float]

class VectorStore(Protocol):
    async def add(self, ids: list[str], embeddings: list[list[float]], documents: list[str], metadatas: list[dict], user_id: str) -> None: ...
    async def query(self, embedding: list[float], user_id: str, n_results: int = 10, where: dict | None = None) -> QueryResult: ...
    async def delete(self, ids: list[str], user_id: str) -> None: ...
    async def get(self, ids: list[str], user_id: str) -> QueryResult: ...
    async def count(self, user_id: str) -> int: ...
