"""Analytics Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field


class Achievement(BaseModel):
    id: str
    name: str
    description: str
    unlocked: bool = False
    unlocked_at: str | None = Field(default=None, alias="unlockedAt")
    model_config = {"populate_by_name": True}


class TopicProgress(BaseModel):
    topic: str
    shorts_completed: int = Field(default=0, alias="shortsCompleted")
    total_shorts: int = Field(default=0, alias="totalShorts")
    mastery: float = 0.0
    model_config = {"populate_by_name": True}


class DashboardResponse(BaseModel):
    streak: dict = Field(default_factory=dict)
    topics_progress: list[TopicProgress] = Field(default_factory=list, alias="topicsProgress")
    total_shorts_completed: int = Field(default=0, alias="totalShortsCompleted")
    total_time_spent_minutes: float = Field(default=0.0, alias="totalTimeSpentMinutes")
    average_session_minutes: float = Field(default=0.0, alias="averageSessionMinutes")
    learning_velocity: float = Field(default=0.0, alias="learningVelocity")
    achievements: list[Achievement] = Field(default_factory=list)
    model_config = {"populate_by_name": True}
