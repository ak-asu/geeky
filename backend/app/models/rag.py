"""RAG Pydantic schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.common import RAGMode


class RAGQueryRequest(BaseModel):
    question: str
    mode: RAGMode = RAGMode.QA
    top_k: int = Field(default=10, ge=1, le=50)
    session_id: str | None = Field(default=None, alias="sessionId")
    model_config = {"populate_by_name": True}


class RAGCitation(BaseModel):
    short_id: str = Field(alias="shortId")
    title: str = ""
    snippet: str = ""
    model_config = {"populate_by_name": True}


class RAGQueryResponse(BaseModel):
    answer: str
    citations: list[RAGCitation] = Field(default_factory=list)
    follow_up_questions: list[str] = Field(default_factory=list, alias="followUpQuestions")
    mind_map: dict | None = Field(default=None, alias="mindMap")
    model_config = {"populate_by_name": True}


class SearchRequest(BaseModel):
    query: str
    filters: SearchFilters | None = None
    limit: int = Field(default=20, ge=1, le=100)
    cursor: str | None = None


class SearchFilters(BaseModel):
    topic: str | None = None
    difficulty_min: float | None = Field(default=None, alias="difficultyMin")
    difficulty_max: float | None = Field(default=None, alias="difficultyMax")
    read: bool | None = None
    source_id: str | None = Field(default=None, alias="sourceId")
    module_id: str | None = Field(default=None, alias="moduleId")
    sort_by: str | None = Field(default=None, alias="sortBy")
    model_config = {"populate_by_name": True}


class SearchResultItem(BaseModel):
    short_id: str = Field(alias="shortId")
    title: str = ""
    snippet: str = ""
    score: float = 0.0
    topics: list[str] = Field(default_factory=list)
    model_config = {"populate_by_name": True}


class SearchResponse(BaseModel):
    results: list[SearchResultItem] = Field(default_factory=list)
    total: int = 0
    model_config = {"populate_by_name": True}
