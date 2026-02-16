"""Recommendation scorer Protocol."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Protocol

@dataclass
class ScoredShort:
    short_id: str
    score: float
    relevance_score: float = 0.0
    capability_score: float = 0.0
    novelty_score: float = 0.0
    explanation: str = ""

class RecommendationScorer(Protocol):
    async def score(self, user_id: str, short_ids: list[str]) -> list[ScoredShort]: ...
