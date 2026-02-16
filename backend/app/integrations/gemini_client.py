"""Gemini API client wrapper.

Thin wrapper around the google-genai SDK. Used by GeminiEmbedder and GeminiLLM
concrete implementations. Not used directly by services — services depend
on EmbeddingProvider and LLMProvider Protocols.
"""

from __future__ import annotations

import logging
from functools import lru_cache

logger = logging.getLogger(__name__)


@lru_cache
def get_gemini_client():
    """Get or initialize the Gemini API client."""
    from google import genai  # noqa: PLC0415

    from app.config import get_settings  # noqa: PLC0415

    settings = get_settings()
    client = genai.Client(api_key=settings.gemini_api_key)
    logger.info("Gemini API client initialized (model=%s)", settings.gemini_model)
    return client
