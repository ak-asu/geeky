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


class MasteryDistribution(BaseModel):
    new: int = 0
    learning: int = 0
    review: int = 0
    relearning: int = 0
    total: int = 0
    model_config = {"populate_by_name": True}


class StudyActivity(BaseModel):
    date: str
    reviews: int = 0
    time_spent_minutes: float = Field(default=0.0, alias="timeSpentMinutes")
    model_config = {"populate_by_name": True}


class StreakResponse(BaseModel):
    current: int = 0
    longest: int = 0
    last_active_date: str | None = Field(default=None, alias="lastActiveDate")
    weekly_activity: list[bool] = Field(default_factory=lambda: [False] * 7, alias="weeklyActivity")
    model_config = {"populate_by_name": True}


class DashboardResponse(BaseModel):
    streak: StreakResponse = Field(default_factory=StreakResponse)
    topics_progress: list[TopicProgress] = Field(default_factory=list, alias="topicsProgress")
    mastery: MasteryDistribution = Field(default_factory=MasteryDistribution)
    recent_activity: list[StudyActivity] = Field(default_factory=list, alias="recentActivity")
    total_notes: int = Field(default=0, alias="totalNotes")
    total_shorts: int = Field(default=0, alias="totalShorts")
    total_concepts: int = Field(default=0, alias="totalConcepts")
    total_shorts_completed: int = Field(default=0, alias="totalShortsCompleted")
    total_time_spent_minutes: float = Field(default=0.0, alias="totalTimeSpentMinutes")
    average_session_minutes: float = Field(default=0.0, alias="averageSessionMinutes")
    learning_velocity: float = Field(default=0.0, alias="learningVelocity")
    achievements: list[Achievement] = Field(default_factory=list)
    model_config = {"populate_by_name": True}
