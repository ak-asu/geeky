"""Shared Pydantic schemas: pagination, error envelopes, enums."""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


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


# ============================================================
# Shared base model
# ============================================================


class GeekyBaseModel(BaseModel):
    """Project-wide base model with a uniform camelCase alias strategy (M18).

    All Geeky Pydantic models should inherit from this class (directly or via
    ``TimestampMixin``) so that:

    - API responses are consistently camelCase — matching Flutter's JSON keys.
    - ``populate_by_name=True`` lets internal Python code use snake_case field
      names while still accepting the camelCase wire format.
    - Explicit ``Field(alias=...)`` declarations take precedence over the
      auto-generated alias, so existing aliases are not overridden.
    - Request models (NoteCreate, ModuleCreate, …) inherit the same config,
      eliminating the inconsistency where some models accepted camelCase and
      others only accepted snake_case.

    Do NOT apply this to pure-internal dataclasses or error envelopes that are
    never serialised to the API wire format.
    """

    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
    )


class TimestampMixin(GeekyBaseModel):
    """Mixin for created/updated timestamps.

    Inherits camelCase alias config from GeekyBaseModel.  The explicit aliases
    on the fields below are redundant with the auto-generated ones but are
    kept for self-documentation.
    """

    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")
