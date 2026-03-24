"""Note Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel, NoteType, TimestampMixin


class NoteCreate(GeekyBaseModel):
    """Request body for creating a note.

    Inherits camelCase alias generation — Flutter can send either
    ``sourceUrl`` (camelCase) or ``source_url`` (snake_case).
    """

    type: NoteType = NoteType.TEXT
    title: str | None = Field(default=None, max_length=500)
    content: str = Field(min_length=1, max_length=100_000)
    source_url: str | None = Field(default=None, max_length=2048)
    topics: list[str] = Field(default_factory=list, max_length=50)


class NoteUpdate(GeekyBaseModel):
    title: str | None = Field(default=None, max_length=500)
    content: str | None = Field(default=None, min_length=1, max_length=100_000)
    topics: list[str] | None = Field(default=None, max_length=50)


class NoteDocument(TimestampMixin):
    """Firestore document model for a note.

    All snake_case field names have auto-generated camelCase aliases via the
    inherited GeekyBaseModel config.  Explicit ``Field(alias=...)`` entries
    below are kept for self-documentation but are functionally redundant.
    """

    id: str = ""
    type: NoteType = NoteType.TEXT
    title: str | None = None
    content: str = ""
    extracted_text: str | None = Field(default=None, alias="extractedText")
    source_url: str | None = Field(default=None, alias="sourceUrl")
    primary_topic: str | None = Field(default=None, alias="primaryTopic")
    topics: list[str] = Field(default_factory=list)
    media_assets: list[str] = Field(default_factory=list, alias="mediaAssets")
    processed: bool = False
    processing_task_id: str | None = Field(default=None, alias="processingTaskId")
    source_summary: str | None = Field(default=None, alias="sourceSummary")
    suggested_questions: list[str] = Field(default_factory=list, alias="suggestedQuestions")
    metadata: dict = Field(default_factory=dict)
    word_count: int = Field(default=0, alias="wordCount")


class NoteResponse(GeekyBaseModel):
    data: NoteDocument
