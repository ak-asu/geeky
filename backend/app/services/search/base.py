"""Sparse search engine Protocol — abstracts BM25/keyword search."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Protocol

@dataclass
class SparseResult:
    document_id: str
    score: float

class SparseSearchEngine(Protocol):
    def index(self, corpus: list[str], ids: list[str]) -> None: ...
    def search(self, query: str, top_k: int = 10) -> list[SparseResult]: ...
    def remove(self, ids: list[str]) -> None: ...
