"""Concept Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import TimestampMixin


class BKTParams(BaseModel):
    p_learn: float = Field(default=0.3, alias="pLearn")
    p_slip: float = Field(default=0.1, alias="pSlip")
    p_guess: float = Field(default=0.25, alias="pGuess")
    p_known: float = Field(default=0.0, alias="pKnown")
    model_config = {"populate_by_name": True}


class TemporalEvent(BaseModel):
    timestamp: str
    event: str


class ConceptDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    name: str = ""
    description: str = ""
    level: int = 1
    aliases: list[str] = Field(default_factory=list)
    article_ids: list[str] = Field(default_factory=list, alias="articleIds")
    importance_score: float = Field(default=0.0, alias="importanceScore")
    mastery_state: str = Field(default="unknown", alias="masteryState")
    bkt_params: BKTParams = Field(default_factory=BKTParams, alias="bktParams")
    temporal_history: list[TemporalEvent] = Field(default_factory=list, alias="temporalHistory")
