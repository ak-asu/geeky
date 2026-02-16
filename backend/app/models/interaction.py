"""Interaction Pydantic schemas."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from app.models.common import FeedbackType, InteractionType, TimestampMixin


class InteractionDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    article_id: str = Field(default="", alias="articleId")
    type: InteractionType = InteractionType.VIEW
    timestamp: datetime | None = None
    time_spent: float = Field(default=0.0, alias="timeSpent")
    scroll_depth: float = Field(default=0.0, alias="scrollDepth")
    feedback_type: FeedbackType | None = Field(default=None, alias="feedbackType")
    navigation_direction: str | None = Field(default=None, alias="navigationDirection")
    from_article_id: str | None = Field(default=None, alias="fromArticleId")
    device: str | None = None
    session_id: str | None = Field(default=None, alias="sessionId")


class InteractionBatchRequest(BaseModel):
    interactions: list[InteractionCreate]


class InteractionCreate(BaseModel):
    article_id: str = Field(alias="articleId")
    type: InteractionType
    timestamp: datetime
    time_spent: float = Field(default=0.0, alias="timeSpent")
    scroll_depth: float = Field(default=0.0, alias="scrollDepth")
    feedback_type: FeedbackType | None = Field(default=None, alias="feedbackType")
    navigation_direction: str | None = Field(default=None, alias="navigationDirection")
    from_article_id: str | None = Field(default=None, alias="fromArticleId")
    device: str | None = None
    session_id: str | None = Field(default=None, alias="sessionId")
    model_config = {"populate_by_name": True}


class InteractionBatchResponse(BaseModel):
    synced: int = 0
    failed: int = 0
