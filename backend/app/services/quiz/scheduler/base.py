"""Spaced repetition scheduler Protocol."""
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Protocol

class CardState(str, Enum):
    NEW = "new"
    LEARNING = "learning"
    REVIEW = "review"
    RELEARNING = "relearning"

@dataclass
class ReviewCard:
    card_id: str
    stability: float
    difficulty: float
    due_date: datetime
    last_review_date: datetime | None
    reps: int
    lapses: int
    state: CardState

class SpacedRepetitionScheduler(Protocol):
    def schedule(self, card: ReviewCard, rating: int) -> ReviewCard: ...
    def get_retrievability(self, card: ReviewCard) -> float: ...
