"""Mock LLM provider for testing."""

from __future__ import annotations

from typing import TypeVar

from pydantic import BaseModel

T = TypeVar("T", bound=BaseModel)


class MockLLMProvider:
    """Mock LLM that returns predictable responses for testing."""

    def __init__(self, default_response: str = "Mock LLM response") -> None:
        self._default_response = default_response
        self.calls: list[dict] = []

    async def generate(
        self,
        prompt: str,
        *,
        system: str | None = None,
        temperature: float = 0.7,
        max_tokens: int | None = None,
    ) -> str:
        self.calls.append({"prompt": prompt, "system": system})
        return self._default_response

    async def generate_structured(
        self,
        prompt: str,
        response_model: type[T],
        *,
        system: str | None = None,
        temperature: float = 0.3,
    ) -> T:
        self.calls.append({"prompt": prompt, "response_model": response_model.__name__})
        # Return a default instance of the model
        return response_model()
