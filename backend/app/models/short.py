"""Short Pydantic schemas."""
from __future__ import annotations

from pydantic import Field, field_validator

from app.models.common import GeekyBaseModel, TimestampMixin


class ShortEngagement(GeekyBaseModel):
    views: int = 0
    completions: int = 0
    skips: int = 0
    saves: int = 0
    shares: int = 0
    avg_time_spent: float = Field(default=0.0, alias="avgTimeSpent")
    score: float = 0.0


class ConflictFlag(GeekyBaseModel):
    claim: str
    sources: list[str] = Field(default_factory=list)


class ShortDocument(TimestampMixin):
    id: str = ""
    user_id: str = Field(default="", alias="userId")
    title: str = ""
    content: str = ""
    summary: str = ""
    topics: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    prerequisites: list[str] = Field(default_factory=list)
    related: list[str] = Field(default_factory=list)
    citations: list[str] = Field(default_factory=list)
    difficulty: float = 0.5
    level: int = 1
    prompts: list[str] = Field(default_factory=list)
    concept_ids: list[str] = Field(default_factory=list, alias="conceptIds")
    media: list[str] = Field(default_factory=list)
    engagement: ShortEngagement = Field(default_factory=ShortEngagement)
    chunk_ids: list[str] = Field(default_factory=list, alias="chunkIds")
    version: int = 1
    conflict_flags: list[ConflictFlag] = Field(default_factory=list, alias="conflictFlags")

    @field_validator("citations", mode="before")
    @classmethod
    def _coerce_citations(cls, v: object) -> list[str]:
        """Handle legacy Firestore format where citations were stored as dicts."""
        if not isinstance(v, list):
            return []
        result = []
        for item in v:
            if isinstance(item, str):
                result.append(item)
            elif isinstance(item, dict):
                chunk_id = item.get("chunkId") or item.get("noteId") or ""
                if chunk_id:
                    result.append(chunk_id)
        return result
