"""Module Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import ModuleType, TimestampMixin


class ModuleCreate(BaseModel):
    name: str
    description: str = ""
    topics: list[str] = Field(default_factory=list)
    short_ids: list[str] = Field(default_factory=list, alias="shortIds")
    type: ModuleType = ModuleType.MANUAL
    is_free: bool = Field(default=False, alias="isFree")
    model_config = {"populate_by_name": True}


class ModuleUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    topics: list[str] | None = None
    short_ids: list[str] | None = Field(default=None, alias="shortIds")
    model_config = {"populate_by_name": True}


class ModuleDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    name: str = ""
    description: str = ""
    topics: list[str] = Field(default_factory=list)
    short_ids: list[str] = Field(default_factory=list, alias="shortIds")
    type: ModuleType = ModuleType.MANUAL
    completed_shorts: int = Field(default=0, alias="completedShorts")
    total_shorts: int = Field(default=0, alias="totalShorts")
    current_position: int = Field(default=0, alias="currentPosition")
    estimated_minutes_remaining: int = Field(default=0, alias="estimatedMinutesRemaining")
    is_free: bool = Field(default=False, alias="isFree")
    adaptive_rules: dict = Field(default_factory=dict, alias="adaptiveRules")
