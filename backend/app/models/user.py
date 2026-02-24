"""User Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import SubscriptionTier, TimestampMixin


class ReadingPatterns(BaseModel):
    avg_session_duration: float = Field(default=0.0, alias="avgSessionDuration")
    sessions_per_week: float = Field(default=0.0, alias="sessionsPerWeek")
    completion_rate: float = Field(default=0.0, alias="completionRate")
    return_rate: float = Field(default=0.0, alias="returnRate")
    model_config = {"populate_by_name": True}


class StreakInfo(BaseModel):
    current: int = 0
    longest: int = 0
    last_active_date: str | None = Field(default=None, alias="lastActiveDate")
    weekly_activity: list[bool] = Field(default_factory=lambda: [False]*7, alias="weeklyActivity")
    model_config = {"populate_by_name": True}


class DomainExpertise(BaseModel):
    level: float = 0.0
    confidence: float = 0.0
    last_updated: str | None = Field(default=None, alias="lastUpdated")
    model_config = {"populate_by_name": True}


class UserDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    name: str = ""
    email: str = ""
    avatar_url: str | None = Field(default=None, alias="avatarUrl")
    interests: list[str] = Field(default_factory=list)
    goals: list[str] = Field(default_factory=list)
    topic_familiarity: dict[str, float] = Field(default_factory=dict, alias="topicFamiliarity")
    expertise_level: str = Field(default="beginner", alias="expertiseLevel")
    domain_expertise: dict[str, DomainExpertise] = Field(default_factory=dict, alias="domainExpertise")
    learning_mode: str = Field(default="visual", alias="learningMode")
    depth_preference: str = Field(default="detailed", alias="depthPreference")
    subscription_tier: SubscriptionTier = Field(default=SubscriptionTier.FREE, alias="subscriptionTier")
    streak: StreakInfo = Field(default_factory=StreakInfo)
    reading_patterns: ReadingPatterns = Field(default_factory=ReadingPatterns, alias="readingPatterns")
    onboarding_completed: bool = Field(default=False, alias="onboardingCompleted")
    fcm_tokens: list[str] = Field(default_factory=list, alias="fcmTokens")
    # RAG quota tracking (enforced by SubscriptionService)
    rag_queries_today: int = Field(default=0, alias="ragQueriesToday")
    rag_queries_date: str = Field(default="", alias="ragQueriesDate")
    # Location preferences (city/state level only, opt-in)
    home_region: str | None = Field(default=None, alias="homeRegion", max_length=200)
    location_enabled: bool = Field(default=False, alias="locationEnabled")


class UserProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    interests: list[str] | None = Field(default=None, max_length=50)
    goals: list[str] | None = Field(default=None, max_length=20)
    learning_mode: str | None = Field(default=None, alias="learningMode", max_length=50)
    depth_preference: str | None = Field(default=None, alias="depthPreference", max_length=50)
    onboarding_completed: bool | None = Field(default=None, alias="onboardingCompleted")
    home_region: str | None = Field(default=None, alias="homeRegion", max_length=200)
    location_enabled: bool | None = Field(default=None, alias="locationEnabled")
    model_config = {"populate_by_name": True}
