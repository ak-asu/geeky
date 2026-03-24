"""Shared mathematical utilities for embedding-space operations.

Uses NumPy for vectorised operations on high-dimensional embeddings
(gemini-embedding-001 at 768 dims).  A single NumPy BLAS call is
50-100× faster than the equivalent pure-Python loop for 768-element
float vectors.
"""

from __future__ import annotations

import logging

import numpy as np

logger = logging.getLogger(__name__)


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two embedding vectors.

    Args:
        a: First embedding vector.
        b: Second embedding vector (must be the same length as *a*).

    Returns:
        Cosine similarity in [-1, 1].  Returns 0.0 for zero-norm vectors.
    """
    va = np.asarray(a, dtype=np.float32)
    vb = np.asarray(b, dtype=np.float32)
    norm_a = np.linalg.norm(va)
    norm_b = np.linalg.norm(vb)
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return float(np.dot(va, vb) / (norm_a * norm_b))


def cosine_similarity_matrix(
    queries: list[list[float]],
    candidates: list[list[float]],
) -> list[list[float]]:
    """Compute a full query×candidate cosine similarity matrix in one BLAS call.

    Args:
        queries: List of query embedding vectors (shape [Q, D]).
        candidates: List of candidate embedding vectors (shape [C, D]).

    Returns:
        2-D list of shape [Q, C] with cosine similarities.
    """
    q = np.asarray(queries, dtype=np.float32)   # (Q, D)
    c = np.asarray(candidates, dtype=np.float32)  # (C, D)

    # Row-wise L2 norms; clip to 1e-10 to avoid div-by-zero
    q_norms = np.linalg.norm(q, axis=1, keepdims=True).clip(min=1e-10)
    c_norms = np.linalg.norm(c, axis=1, keepdims=True).clip(min=1e-10)

    q_normed = q / q_norms   # (Q, D)
    c_normed = c / c_norms   # (C, D)

    sim_matrix = q_normed @ c_normed.T  # (Q, C)
    return sim_matrix.tolist()
