"""Mock embedding provider for testing."""

from __future__ import annotations

import hashlib


class MockEmbeddingProvider:
    """Mock embedder that returns deterministic vectors based on text hash."""

    def __init__(self, dimensions: int = 768) -> None:
        self._dimensions = dimensions
        self.calls: list[dict] = []

    @property
    def dimensions(self) -> int:
        return self._dimensions

    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        self.calls.append({"action": "embed_texts", "count": len(texts)})
        return [self._deterministic_vector(t) for t in texts]

    async def embed_query(self, query: str) -> list[float]:
        self.calls.append({"action": "embed_query", "query": query})
        return self._deterministic_vector(query)

    def _deterministic_vector(self, text: str) -> list[float]:
        """Generate a deterministic vector from text for reproducible tests."""
        h = hashlib.sha256(text.encode()).digest()
        # Use hash bytes to seed vector values between -1 and 1
        values = []
        for i in range(self._dimensions):
            byte_val = h[i % len(h)]
            values.append((byte_val / 127.5) - 1.0)
        return values
