"""RAG Pydantic schemas."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel, RAGMode


class RAGQueryRequest(GeekyBaseModel):
    question: str = Field(min_length=1, max_length=1000)
    mode: RAGMode = RAGMode.QA
    top_k: int = Field(default=10, ge=1, le=50)
    session_id: str | None = Field(default=None, alias="sessionId")


class RAGCitation(GeekyBaseModel):
    short_id: str = Field(alias="shortId")
    title: str = ""
    snippet: str = ""


class RAGQueryResponse(GeekyBaseModel):
    answer: str
    citations: list[RAGCitation] = Field(default_factory=list)
    follow_up_questions: list[str] = Field(default_factory=list, alias="followUpQuestions")
    mind_map: dict | None = Field(default=None, alias="mindMap")


class SearchRequest(GeekyBaseModel):
    query: str = Field(min_length=1, max_length=500)
    filters: SearchFilters | None = None
    limit: int = Field(default=20, ge=1, le=100)
    cursor: str | None = None


class SearchFilters(GeekyBaseModel):
    topic: str | None = None
    difficulty_min: float | None = Field(default=None, alias="difficultyMin")
    difficulty_max: float | None = Field(default=None, alias="difficultyMax")
    read: bool | None = None
    source_id: str | None = Field(default=None, alias="sourceId")
    module_id: str | None = Field(default=None, alias="moduleId")
    sort_by: str | None = Field(default=None, alias="sortBy")


class SearchResultItem(GeekyBaseModel):
    short_id: str = Field(alias="shortId")
    title: str = ""
    snippet: str = ""
    score: float = 0.0
    topics: list[str] = Field(default_factory=list)


class SearchResponse(GeekyBaseModel):
    results: list[SearchResultItem] = Field(default_factory=list)
    total: int = 0
