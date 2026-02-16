"""Reranker Protocol — abstracts cross-encoder reranking."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Protocol

@dataclass
class RankedDocument:
    document_id: str
    content: str
    score: float
    metadata: dict | None = None

class Reranker(Protocol):
    async def rerank(self, query: str, documents: list[str], document_ids: list[str], top_k: int = 10) -> list[RankedDocument]: ...
