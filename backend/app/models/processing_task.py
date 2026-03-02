"""Processing task Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel, ProcessingStatus, TimestampMixin


class StageStatus(GeekyBaseModel):
    status: ProcessingStatus = ProcessingStatus.PENDING
    started_at: str | None = Field(default=None, alias="startedAt")
    completed_at: str | None = Field(default=None, alias="completedAt")
    error: str | None = None


class ProcessingTaskDocument(TimestampMixin):
    id: str = ""
    user_id: str = Field(default="", alias="userId")
    note_id: str = Field(default="", alias="noteId")
    status: ProcessingStatus = ProcessingStatus.PENDING
    stages: dict[str, StageStatus] = Field(default_factory=dict)
    error: str | None = None
