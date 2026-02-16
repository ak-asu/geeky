"""Short Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import TimestampMixin


class ShortEngagement(BaseModel):
    model_config = {"populate_by_name": True}

    views: int = 0
    completions: int = 0
    skips: int = 0
    saves: int = 0
    shares: int = 0
    avg_time_spent: float = Field(default=0.0, alias="avgTimeSpent")
    score: float = 0.0


class Citation(BaseModel):
    note_id: str = Field(alias="noteId")
    chunk_id: str = Field(alias="chunkId")
    model_config = {"populate_by_name": True}


class ConflictFlag(BaseModel):
    claim: str
    sources: list[str] = Field(default_factory=list)


class ShortDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    title: str = ""
    content: str = ""
    summary: str = ""
    topics: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    prerequisites: list[str] = Field(default_factory=list)
    related: list[str] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
    difficulty: float = 0.5
    level: int = 1
    prompts: list[str] = Field(default_factory=list)
    concept_ids: list[str] = Field(default_factory=list, alias="conceptIds")
    media: list[str] = Field(default_factory=list)
    engagement: ShortEngagement = Field(default_factory=ShortEngagement)
    chunk_ids: list[str] = Field(default_factory=list, alias="chunkIds")
    version: int = 1
    conflict_flags: list[ConflictFlag] = Field(default_factory=list, alias="conflictFlags")


class ShortListResponse(BaseModel):
    data: list[ShortDocument]
    meta: dict = Field(default_factory=dict)
