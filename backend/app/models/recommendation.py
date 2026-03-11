"""Recommendation Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel


class ScoredShortResponse(GeekyBaseModel):
    """API response model for a single ranked feed item."""

    short_id: str = Field(alias="shortId")
    score: float
    relevance_score: float = Field(alias="relevanceScore")
    capability_score: float = Field(alias="capabilityScore")
    novelty_score: float = Field(alias="noveltyScore")
    explanation: str
