"""Quiz attempt Pydantic schemas for tracking quiz history."""
from __future__ import annotations

from pydantic import Field

from app.models.common import QuizQuestionType, TimestampMixin


class QuizAttemptAnswer(TimestampMixin):
    model_config = {"populate_by_name": True}

    question_id: str = Field(default="", alias="questionId")
    question_type: QuizQuestionType = Field(default=QuizQuestionType.MCQ, alias="questionType")
    user_answer: str = Field(default="", alias="userAnswer")
    correct_answer: str = Field(default="", alias="correctAnswer")
    correct: bool = False
    time_spent_ms: int = Field(default=0, alias="timeSpentMs")


class QuizAttemptDocument(TimestampMixin):
    """Records a single quiz attempt (AL-04)."""

    model_config = {"populate_by_name": True}

    id: str = ""
    short_ids: list[str] = Field(default_factory=list, alias="shortIds")
    module_id: str | None = Field(default=None, alias="moduleId")
    topic: str | None = None
    answers: list[QuizAttemptAnswer] = Field(default_factory=list)
    score: float = 0.0
    total_questions: int = Field(default=0, alias="totalQuestions")
    correct_count: int = Field(default=0, alias="correctCount")
