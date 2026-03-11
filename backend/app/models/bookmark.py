"""Bookmark Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import TimestampMixin


class BookmarkDocument(TimestampMixin):
    id: str = ""
    short_id: str = Field(default="", alias="shortId")
