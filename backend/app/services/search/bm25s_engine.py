"""BM25S sparse search engine — implements SparseSearchEngine Protocol.

Uses rank_bm25 (BM25Okapi) for keyword-based sparse retrieval.
Maintains an in-memory index per instance with thread-safe updates.
"""

from __future__ import annotations

import asyncio
import logging
import re
import threading

from app.services.search.base import SparseResult

logger = logging.getLogger(__name__)


def _tokenize(text: str) -> list[str]:
    """Simple whitespace + punctuation tokenizer with lowercasing."""
    return re.findall(r"\w+", text.lower())


class BM25SSearchEngine:
    """Sparse search engine backed by BM25Okapi from rank_bm25.

    Thread-safe index operations via a reentrant lock.
    All public methods are sync (Protocol contract); callers should
    use ``asyncio.to_thread()`` if needed.
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._ids: list[str] = []
        self._corpus_tokens: list[list[str]] = []
        self._bm25 = None
        self._id_to_idx: dict[str, int] = {}

    def _rebuild_bm25(self) -> None:
        """Rebuild the BM25 index from the current corpus."""
        if not self._corpus_tokens:
            self._bm25 = None
            return

        from rank_bm25 import BM25Okapi  # noqa: PLC0415

        self._bm25 = BM25Okapi(self._corpus_tokens)

    def index(self, corpus: list[str], ids: list[str]) -> None:
        """Index a corpus of documents with corresponding IDs.

        Replaces any existing index entirely.
        """
        if len(corpus) != len(ids):
            msg = f"corpus length ({len(corpus)}) != ids length ({len(ids)})"
            raise ValueError(msg)

        with self._lock:
            self._ids = list(ids)
            self._corpus_tokens = [_tokenize(doc) for doc in corpus]
            self._id_to_idx = {doc_id: i for i, doc_id in enumerate(self._ids)}
            self._rebuild_bm25()

        logger.info("BM25 index built with %d documents", len(ids))

    def add(self, corpus: list[str], ids: list[str]) -> None:
        """Incrementally add documents to the existing index."""
        if len(corpus) != len(ids):
            msg = f"corpus length ({len(corpus)}) != ids length ({len(ids)})"
            raise ValueError(msg)

        with self._lock:
            for doc_id, text in zip(ids, corpus):
                if doc_id in self._id_to_idx:
                    # Update existing document
                    idx = self._id_to_idx[doc_id]
                    self._corpus_tokens[idx] = _tokenize(text)
                else:
                    # Append new document
                    self._id_to_idx[doc_id] = len(self._ids)
                    self._ids.append(doc_id)
                    self._corpus_tokens.append(_tokenize(text))
            self._rebuild_bm25()

    def search(self, query: str, top_k: int = 10) -> list[SparseResult]:
        """Search the index and return ranked results."""
        with self._lock:
            if self._bm25 is None or not self._ids:
                return []

            tokens = _tokenize(query)
            if not tokens:
                return []

            scores = self._bm25.get_scores(tokens)

        # Rank by score descending
        scored = [(self._ids[i], float(scores[i])) for i in range(len(self._ids))]
        scored.sort(key=lambda x: x[1], reverse=True)

        results = []
        for doc_id, score in scored[:top_k]:
            if score > 0:
                results.append(SparseResult(document_id=doc_id, score=score))

        return results

    def remove(self, ids: list[str]) -> None:
        """Remove documents by ID and rebuild the index."""
        ids_to_remove = set(ids)
        with self._lock:
            new_ids = []
            new_tokens = []
            for doc_id, tokens in zip(self._ids, self._corpus_tokens):
                if doc_id not in ids_to_remove:
                    new_ids.append(doc_id)
                    new_tokens.append(tokens)

            self._ids = new_ids
            self._corpus_tokens = new_tokens
            self._id_to_idx = {doc_id: i for i, doc_id in enumerate(self._ids)}
            self._rebuild_bm25()

        logger.info("Removed %d documents from BM25 index", len(ids_to_remove))

    @property
    def size(self) -> int:
        """Number of indexed documents."""
        return len(self._ids)
