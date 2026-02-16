"""Quiz Pydantic schemas."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from app.models.common import QuizQuestionType, TimestampMixin


class QuizQuestion(BaseModel):
    id: str = ""
    text: str = ""
    type: QuizQuestionType = QuizQuestionType.MCQ
    options: list[str] = Field(default_factory=list)
    correct_answer: str = Field(default="", alias="correctAnswer")
    explanation: str = ""
    topic: str = ""
    difficulty: float = 0.5
    model_config = {"populate_by_name": True}


class QuizGenerateRequest(BaseModel):
    short_ids: list[str] | None = Field(default=None, alias="shortIds")
    module_id: str | None = Field(default=None, alias="moduleId")
    topic: str | None = None
    types: list[QuizQuestionType] = Field(default_factory=lambda: [QuizQuestionType.MCQ])
    count: int = Field(default=5, ge=1, le=20)
    model_config = {"populate_by_name": True}


class QuizAnswer(BaseModel):
    question_id: str = Field(alias="questionId")
    answer: str
    correct_answer: str = Field(alias="correctAnswer")
    model_config = {"populate_by_name": True}


class QuizGradeRequest(BaseModel):
    short_ids: list[str] = Field(default_factory=list, alias="shortIds")
    answers: list[QuizAnswer]
    model_config = {"populate_by_name": True}


class QuizGradeResult(BaseModel):
    question_id: str = Field(alias="questionId")
    correct: bool
    explanation: str = ""
    model_config = {"populate_by_name": True}


class QuizCardDocument(TimestampMixin):
    model_config = {"populate_by_name": True}

    id: str = ""
    article_id: str = Field(default="", alias="articleId")
    stability: float = 0.0
    difficulty: float = 0.3
    due_date: datetime | None = Field(default=None, alias="dueDate")
    last_review_date: datetime | None = Field(default=None, alias="lastReviewDate")
    reps: int = 0
    lapses: int = 0
    state: str = "new"
    questions: list[QuizQuestion] = Field(default_factory=list)


class ReviewSubmitRequest(BaseModel):
    rating: int = Field(ge=1, le=4, description="1=Again, 2=Hard, 3=Good, 4=Easy")
