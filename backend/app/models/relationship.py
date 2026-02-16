"""Relationship Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import TimestampMixin


class RelationshipDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    source_id: str = Field(default="", alias="sourceId")
    target_id: str = Field(default="", alias="targetId")
    type: str = "related"
    strength: float = 1.0
    confidence: float = 1.0
    evidence: str | None = None
    short_ids: list[str] = Field(default_factory=list, alias="shortIds")
    is_dynamic: bool = Field(default=False, alias="isDynamic")
