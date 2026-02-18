"""Gemini LLM provider — implements LLMProvider Protocol.

Uses google-genai SDK with gemini-2.5-flash. Supports both free-text
generation and structured output via Pydantic models.
"""

from __future__ import annotations

import asyncio
import logging
from typing import TypeVar

from pydantic import BaseModel

from app.exceptions import ExternalServiceError

logger = logging.getLogger(__name__)

T = TypeVar("T", bound=BaseModel)

# Retry config
_MAX_RETRIES = 3
_BASE_DELAY = 1.0


class GeminiLLM:
    """LLM provider backed by Google Gemini API.

    Args:
        api_key: Gemini API key.
        model: Gemini model name (default: gemini-2.5-flash).
        timeout_seconds: Per-request wall-clock timeout (default 30 s).
    """

    def __init__(
        self,
        api_key: str,
        model: str = "gemini-2.5-flash",
        timeout_seconds: float = 30.0,
    ) -> None:
        from google import genai  # noqa: PLC0415

        self._client = genai.Client(api_key=api_key)
        self._model = model
        self._timeout = timeout_seconds

    async def generate(
        self,
        prompt: str,
        *,
        system: str | None = None,
        temperature: float = 0.7,
        max_tokens: int | None = None,
    ) -> str:
        """Generate free-text response with exponential backoff on rate limits."""
        from google.genai import types  # noqa: PLC0415

        config = types.GenerateContentConfig(
            temperature=temperature,
            max_output_tokens=max_tokens,
            system_instruction=system,
        )

        for attempt in range(_MAX_RETRIES):
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(
                        self._client.models.generate_content,
                        model=self._model,
                        contents=prompt,
                        config=config,
                    ),
                    timeout=self._timeout,
                )
                return response.text or ""
            except asyncio.TimeoutError:
                logger.error("Gemini generate timed out after %.1fs", self._timeout)
                raise ExternalServiceError("Gemini", f"Request timed out after {self._timeout}s")
            except Exception as exc:
                if _is_rate_limit(exc) and attempt < _MAX_RETRIES - 1:
                    delay = _BASE_DELAY * (2**attempt)
                    logger.warning("Gemini rate limited, retrying in %.1fs (attempt %d)", delay, attempt + 1)
                    await asyncio.sleep(delay)
                    continue
                logger.error("Gemini generation failed: %s", exc)
                raise ExternalServiceError("Gemini", str(exc)) from exc

        raise ExternalServiceError("Gemini", "Max retries exceeded")

    async def generate_structured(
        self,
        prompt: str,
        response_model: type[T],
        *,
        system: str | None = None,
        temperature: float = 0.3,
    ) -> T:
        """Generate structured output parsed into a Pydantic model."""
        from google.genai import types  # noqa: PLC0415

        config = types.GenerateContentConfig(
            temperature=temperature,
            system_instruction=system,
            response_mime_type="application/json",
            response_schema=response_model,
        )

        for attempt in range(_MAX_RETRIES):
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(
                        self._client.models.generate_content,
                        model=self._model,
                        contents=prompt,
                        config=config,
                    ),
                    timeout=self._timeout,
                )
                raw_text = response.text or "{}"
                return response_model.model_validate_json(raw_text)
            except asyncio.TimeoutError:
                logger.error("Gemini generate_structured timed out after %.1fs", self._timeout)
                raise ExternalServiceError("Gemini", f"Request timed out after {self._timeout}s")
            except Exception as exc:
                if _is_rate_limit(exc) and attempt < _MAX_RETRIES - 1:
                    delay = _BASE_DELAY * (2**attempt)
                    logger.warning("Gemini rate limited, retrying in %.1fs (attempt %d)", delay, attempt + 1)
                    await asyncio.sleep(delay)
                    continue
                logger.error("Gemini structured generation failed: %s", exc)
                raise ExternalServiceError("Gemini", str(exc)) from exc

        raise ExternalServiceError("Gemini", "Max retries exceeded")


def _is_rate_limit(exc: Exception) -> bool:
    """Check if an exception indicates a rate limit error."""
    msg = str(exc).lower()
    return "429" in msg or "rate" in msg or "quota" in msg or "resource_exhausted" in msg
