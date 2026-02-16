"""Cross-encoder reranker — implements Reranker Protocol.

Uses sentence-transformers CrossEncoder (ms-marco-MiniLM-L-6-v2) to
score query-document pairs for reranking. Model is loaded lazily
and cached for the lifetime of the instance.
"""

from __future__ import annotations

import asyncio
import logging

from app.exceptions import ExternalServiceError
from app.services.rag.reranker.base import RankedDocument

logger = logging.getLogger(__name__)

_DEFAULT_MODEL = "cross-encoder/ms-marco-MiniLM-L-6-v2"


class CrossEncoderReranker:
    """Reranker backed by a cross-encoder model.

    Args:
        model_name: HuggingFace model identifier for the cross-encoder.
    """

    def __init__(self, model_name: str = _DEFAULT_MODEL) -> None:
        self._model_name = model_name
        self._model = None

    def _get_model(self):
        """Lazily load the cross-encoder model."""
        if self._model is None:
            from sentence_transformers import CrossEncoder  # noqa: PLC0415

            self._model = CrossEncoder(self._model_name)
            logger.info("Loaded cross-encoder model: %s", self._model_name)
        return self._model

    async def rerank(
        self,
        query: str,
        documents: list[str],
        document_ids: list[str],
        top_k: int = 10,
    ) -> list[RankedDocument]:
        """Rerank documents by cross-encoder relevance score.

        Args:
            query: The search query.
            documents: Document texts to rerank.
            document_ids: Corresponding document IDs.
            top_k: Maximum number of results to return.

        Returns:
            Reranked documents sorted by score descending.
        """
        if not documents:
            return []

        if len(documents) != len(document_ids):
            msg = f"documents ({len(documents)}) != document_ids ({len(document_ids)})"
            raise ValueError(msg)

        try:
            pairs = [(query, doc) for doc in documents]
            scores = await asyncio.to_thread(self._predict, pairs)
        except Exception as exc:
            logger.error("Cross-encoder reranking failed: %s", exc)
            raise ExternalServiceError("CrossEncoder", str(exc)) from exc

        # Create scored documents
        ranked = []
        for doc_id, doc_text, score in zip(document_ids, documents, scores):
            ranked.append(
                RankedDocument(
                    document_id=doc_id,
                    content=doc_text,
                    score=float(score),
                )
            )

        # Sort by score descending
        ranked.sort(key=lambda r: r.score, reverse=True)
        return ranked[:top_k]

    def _predict(self, pairs: list[tuple[str, str]]) -> list[float]:
        """Run cross-encoder prediction (CPU-bound, runs in thread)."""
        model = self._get_model()
        return model.predict(pairs).tolist()
