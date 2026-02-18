"""Gemini embedding provider — implements EmbeddingProvider Protocol.

Uses gemini-embedding-001 at 768 dimensions with batch support
and exponential backoff for rate limits.
"""

from __future__ import annotations

import asyncio
import logging

from app.exceptions import ExternalServiceError

logger = logging.getLogger(__name__)

_MAX_RETRIES = 3
_BASE_DELAY = 1.0
_DEFAULT_BATCH_SIZE = 100


class GeminiEmbedder:
    """Embedding provider backed by Gemini embedding API.

    Args:
        api_key: Gemini API key.
        model: Embedding model name.
        dimensions: Output vector dimensions.
        batch_size: Max texts per API call.
    """

    def __init__(
        self,
        api_key: str,
        model: str = "models/embedding-001",
        dimensions: int = 768,
        batch_size: int = _DEFAULT_BATCH_SIZE,
        timeout_seconds: float = 15.0,
    ) -> None:
        from google import genai  # noqa: PLC0415

        self._client = genai.Client(api_key=api_key)
        self._model = model
        self._dimensions = dimensions
        self._batch_size = batch_size
        self._timeout = timeout_seconds

    @property
    def dimensions(self) -> int:
        return self._dimensions

    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        """Embed a list of texts, batching as needed."""
        if not texts:
            return []

        all_embeddings: list[list[float]] = []
        for i in range(0, len(texts), self._batch_size):
            batch = texts[i : i + self._batch_size]
            embeddings = await self._embed_batch(batch)
            all_embeddings.extend(embeddings)

        return all_embeddings

    async def embed_query(self, query: str) -> list[float]:
        """Embed a single query text."""
        results = await self._embed_batch([query])
        return results[0]

    async def _embed_batch(self, texts: list[str]) -> list[list[float]]:
        """Embed a single batch with retry logic and timeout."""
        from google.genai import types  # noqa: PLC0415

        for attempt in range(_MAX_RETRIES):
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(
                        self._client.models.embed_content,
                        model=self._model,
                        contents=texts,
                        config=types.EmbedContentConfig(
                            output_dimensionality=self._dimensions,
                        ),
                    ),
                    timeout=self._timeout,
                )
                return [e.values for e in response.embeddings]
            except asyncio.TimeoutError:
                logger.error("Gemini embedding timed out after %.1fs", self._timeout)
                raise ExternalServiceError("Gemini Embeddings", f"Request timed out after {self._timeout}s")
            except Exception as exc:
                if _is_rate_limit(exc) and attempt < _MAX_RETRIES - 1:
                    delay = _BASE_DELAY * (2**attempt)
                    logger.warning("Gemini embedding rate limited, retrying in %.1fs", delay)
                    await asyncio.sleep(delay)
                    continue
                logger.error("Gemini embedding failed: %s", exc)
                raise ExternalServiceError("Gemini Embeddings", str(exc)) from exc

        raise ExternalServiceError("Gemini Embeddings", "Max retries exceeded")


def _is_rate_limit(exc: Exception) -> bool:
    msg = str(exc).lower()
    return "429" in msg or "rate" in msg or "quota" in msg or "resource_exhausted" in msg
