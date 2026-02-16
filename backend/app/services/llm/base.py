"""LLM provider Protocol — abstracts text generation."""
from __future__ import annotations
from typing import Protocol, TypeVar
from pydantic import BaseModel

T = TypeVar("T", bound=BaseModel)

class LLMProvider(Protocol):
    async def generate(self, prompt: str, *, system: str | None = None, temperature: float = 0.7, max_tokens: int | None = None) -> str: ...
    async def generate_structured(self, prompt: str, response_model: type[T], *, system: str | None = None, temperature: float = 0.3) -> T: ...
