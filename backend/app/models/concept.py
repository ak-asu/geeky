"""Concept Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel, TimestampMixin


class BKTParams(GeekyBaseModel):
    p_learn: float = Field(default=0.3, alias="pLearn")
    p_slip: float = Field(default=0.1, alias="pSlip")
    p_guess: float = Field(default=0.25, alias="pGuess")
    p_known: float = Field(default=0.0, alias="pKnown")


class TemporalEvent(GeekyBaseModel):
    timestamp: str
    event: str


class ConceptDocument(TimestampMixin):
    id: str = ""
    name: str = ""
    description: str = ""
    entity_type: str = Field(default="concept", alias="entityType")
    level: int = 1
    aliases: list[str] = Field(default_factory=list)
    article_ids: list[str] = Field(default_factory=list, alias="articleIds")
    short_ids: list[str] = Field(default_factory=list, alias="shortIds")
    importance_score: float = Field(default=0.0, alias="importanceScore")
    mastery_state: str = Field(default="unknown", alias="masteryState")
    bkt_params: BKTParams = Field(default_factory=BKTParams, alias="bktParams")
    temporal_history: list[TemporalEvent] = Field(default_factory=list, alias="temporalHistory")
