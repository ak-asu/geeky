"""Review state Pydantic schemas for FSRS spaced repetition."""
from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.models.common import TimestampMixin


class ReviewStateDocument(TimestampMixin):
    """Per-short FSRS review state tracking (AL-01, AL-05)."""

    id: str = ""
    short_id: str = Field(default="", alias="shortId")
    stability: float = 0.0
    difficulty: float = 0.3
    due_date: datetime | None = Field(default=None, alias="dueDate")
    last_review_date: datetime | None = Field(default=None, alias="lastReviewDate")
    reps: int = 0
    lapses: int = 0
    state: str = "new"
    elapsed_days: int = Field(default=0, alias="elapsedDays")
    scheduled_days: int = Field(default=0, alias="scheduledDays")
