"""Chunk Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import TimestampMixin


class ChunkDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    note_id: str = Field(default="", alias="noteId")
    content: str = ""
    section_title: str | None = Field(default=None, alias="sectionTitle")
    offset: int = 0
    token_span: int = Field(default=0, alias="tokenSpan")
    quality_score: float = Field(default=1.0, alias="qualityScore")
    hash_sha256: str | None = Field(default=None, alias="hashSha256")
    simhash: str | None = None
    canonical_chunk_id: str | None = Field(default=None, alias="canonicalChunkId")
    dedup_log: dict | None = Field(default=None, alias="dedupLog")
