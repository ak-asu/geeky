"""Shared Pydantic schemas: pagination, error envelopes, enums."""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


# ============================================================
# Enums
# ============================================================


class NoteType(str, Enum):
    TEXT = "text"
    IMAGE = "image"
    AUDIO = "audio"
    LINK = "link"
    VIDEO = "video"
    FILE = "file"


class InteractionType(str, Enum):
    VIEW = "view"
    DONE = "done"
    SKIP = "skip"
    BOOKMARK = "bookmark"
    FEEDBACK = "feedback"


class FeedbackType(str, Enum):
    TOO_EASY = "too_easy"
    TOO_HARD = "too_hard"
    NOT_RELEVANT = "not_relevant"


class ModuleType(str, Enum):
    AUTO = "auto"
    MANUAL = "manual"
    CURATED = "curated"


class SourceType(str, Enum):
    RSS = "rss"
    URL = "url"
    NEWSLETTER = "newsletter"
    MANUAL = "manual"


class SourceStatus(str, Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    ERROR = "error"


class ProcessingStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class NotificationType(str, Enum):
    LEARNING_REMINDER = "learning_reminder"
    ACHIEVEMENT = "achievement"
    NEW_CONTENT = "new_content"
    STREAK = "streak"
    REVIEW = "review"


class QuizQuestionType(str, Enum):
    MCQ = "mcq"
    TRUE_FALSE = "tf"
    FILL_BLANK = "fill_blank"
    OPEN_ENDED = "open_ended"
    SHORT_ANSWER = "short_answer"


class SubscriptionTier(str, Enum):
    FREE = "free"
    PREMIUM = "premium"


class RAGMode(str, Enum):
    QA = "qa"
    STUDY_GUIDE = "study_guide"
    MIND_MAP = "mind_map"
    OUTLINE = "outline"


# ============================================================
# Pagination
# ============================================================


class PaginationMeta(BaseModel):
    """Pagination metadata for list responses."""

    cursor: str | None = None
    has_more: bool = False
    total: int | None = None


class PaginatedResponse(BaseModel):
    """Envelope for paginated list responses."""

    data: list = Field(default_factory=list)
    meta: PaginationMeta = Field(default_factory=PaginationMeta)


# ============================================================
# Error Envelope
# ============================================================


class ErrorDetail(BaseModel):
    """Error detail in API error responses."""

    code: str
    message: str
    detail: str | None = None


class ErrorResponse(BaseModel):
    """Standard error response envelope."""

    error: ErrorDetail


# ============================================================
# Common Request/Response
# ============================================================


class PaginationParams(BaseModel):
    """Common pagination query parameters."""

    limit: int = Field(default=50, ge=1, le=100)
    cursor: str | None = None


class TimestampMixin(BaseModel):
    """Mixin for created/updated timestamps."""

    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")

    model_config = {"populate_by_name": True}
