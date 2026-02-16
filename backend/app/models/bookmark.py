"""Bookmark Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import TimestampMixin


class BookmarkDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    short_id: str = Field(default="", alias="shortId")
