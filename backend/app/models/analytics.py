"""Analytics Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel


class Achievement(GeekyBaseModel):
    id: str
    name: str
    description: str
    unlocked: bool = False
    unlocked_at: str | None = Field(default=None, alias="unlockedAt")


class TopicProgress(GeekyBaseModel):
    topic: str
    shorts_completed: int = Field(default=0, alias="shortsCompleted")
    total_shorts: int = Field(default=0, alias="totalShorts")
    mastery: float = 0.0


class MasteryDistribution(GeekyBaseModel):
    new: int = 0
    learning: int = 0
    review: int = 0
    relearning: int = 0
    total: int = 0


class StudyActivity(GeekyBaseModel):
    date: str
    reviews: int = 0
    time_spent_minutes: float = Field(default=0.0, alias="timeSpentMinutes")


class StreakResponse(GeekyBaseModel):
    current: int = 0
    longest: int = 0
    last_active_date: str | None = Field(default=None, alias="lastActiveDate")
    weekly_activity: list[bool] = Field(default_factory=lambda: [False] * 7, alias="weeklyActivity")


class DashboardResponse(GeekyBaseModel):
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
