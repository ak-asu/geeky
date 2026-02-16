"""Processing task Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import ProcessingStatus, TimestampMixin


class StageStatus(BaseModel):
    status: ProcessingStatus = ProcessingStatus.PENDING
    started_at: str | None = Field(default=None, alias="startedAt")
    completed_at: str | None = Field(default=None, alias="completedAt")
    error: str | None = None
    model_config = {"populate_by_name": True}


class ProcessingTaskDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    user_id: str = Field(default="", alias="userId")
    note_id: str = Field(default="", alias="noteId")
    status: ProcessingStatus = ProcessingStatus.PENDING
    stages: dict[str, StageStatus] = Field(default_factory=dict)
    error: str | None = None
