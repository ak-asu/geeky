"""Module Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel, ModuleType, TimestampMixin


class ModuleCreate(GeekyBaseModel):
    name: str = Field(min_length=1, max_length=300)
    description: str = Field(default="", max_length=5000)
    topics: list[str] = Field(default_factory=list, max_length=50)
    short_ids: list[str] = Field(default_factory=list, alias="shortIds", max_length=500)
    type: ModuleType = ModuleType.MANUAL
    is_free: bool = Field(default=False, alias="isFree")


class ModuleUpdate(GeekyBaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=300)
    description: str | None = Field(default=None, max_length=5000)
    topics: list[str] | None = Field(default=None, max_length=50)
    short_ids: list[str] | None = Field(default=None, alias="shortIds", max_length=500)


class ModuleDocument(TimestampMixin):
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
