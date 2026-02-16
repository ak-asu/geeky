"""Source Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import SourceStatus, SourceType, TimestampMixin


class SourceCreate(BaseModel):
    type: SourceType
    name: str
    url: str
    fetch_frequency: int = Field(default=60, alias="fetchFrequency", description="Minutes between polls")
    default_topics: list[str] = Field(default_factory=list, alias="defaultTopics")
    content_filters: dict = Field(default_factory=dict, alias="contentFilters")
    model_config = {"populate_by_name": True}


class SourceStats(BaseModel):
    total_fetched: int = Field(default=0, alias="totalFetched")
    last_fetch_time: str | None = Field(default=None, alias="lastFetchTime")
    success_rate: float = Field(default=1.0, alias="successRate")
    model_config = {"populate_by_name": True}


class SourceDocument(TimestampMixin):
    id: str = ""
    type: SourceType = SourceType.MANUAL
    name: str = ""
    url: str = ""
    fetch_frequency: int = Field(default=60, alias="fetchFrequency")
    default_topics: list[str] = Field(default_factory=list, alias="defaultTopics")
    content_filters: dict = Field(default_factory=dict, alias="contentFilters")
    status: SourceStatus = SourceStatus.ACTIVE
    health_score: float = Field(default=1.0, alias="healthScore")
    last_checked: str | None = Field(default=None, alias="lastChecked")
    stats: SourceStats = Field(default_factory=SourceStats)
