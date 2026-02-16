"""Quiz generator — generates quizzes from Shorts using LLM.

Generates various question types with KG-informed distractors (AL-04).
"""
from __future__ import annotations

import logging
import uuid
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field

from app.models.common import QuizQuestionType
from app.models.quiz import QuizQuestion

if TYPE_CHECKING:
    from app.repositories.short_repo import ShortRepository
    from app.services.knowledge_graph.query_service import GraphQueryService
    from app.services.llm.base import LLMProvider

logger = logging.getLogger(__name__)


class _GeneratedQuestions(BaseModel):
    """Structured LLM response for quiz generation."""
    questions: list[_GeneratedQuestion] = Field(default_factory=list)


class _GeneratedQuestion(BaseModel):
    """A single generated question."""
    text: str = ""
    type: str = "mcq"
    options: list[str] = Field(default_factory=list)
    correct_answer: str = Field(default="", alias="correctAnswer")
    explanation: str = ""
    difficulty: float = 0.5
    model_config = {"populate_by_name": True}


class QuizGenerator:
    """Generates quiz questions from Short content using LLM.

    Uses KG-related concepts to generate intelligent distractors
    rather than random options (AL-04).

    Dependencies:
    - llm: LLM provider for question generation
    - short_repo: Access to short content
    - graph_query_service: For KG-informed distractors
    """

    def __init__(
        self,
        *,
        llm: LLMProvider,
        short_repo: ShortRepository,
        graph_query_service: GraphQueryService | None = None,
    ) -> None:
        self._llm = llm
        self._short_repo = short_repo
        self._graph_query = graph_query_service

    async def generate(
        self,
        user_id: str,
        *,
        short_ids: list[str] | None = None,
        topic: str | None = None,
        question_types: list[QuizQuestionType] | None = None,
        count: int = 5,
    ) -> list[QuizQuestion]:
        """Generate quiz questions from shorts or topic.

        Args:
            user_id: User ID for data access.
            short_ids: Specific shorts to quiz on.
            topic: Topic to filter shorts by.
            question_types: Types of questions to generate.
            count: Number of questions to generate.

        Returns:
            List of QuizQuestion objects ready for presentation.
        """
        # Gather source content
        shorts_content = await self._gather_content(user_id, short_ids, topic)
        if not shorts_content:
            return []

        types = question_types or [QuizQuestionType.MCQ]
        type_names = ", ".join(t.value for t in types)

        # Get related concepts for distractor generation
        related_concepts: list[str] = []
        if self._graph_query and short_ids:
            for sid in short_ids[:3]:
                short = await self._short_repo.get(user_id, sid)
                if short and short.concept_ids:
                    for cid in short.concept_ids[:2]:
                        related = await self._graph_query.get_related_concepts(user_id, cid, limit=5)
                        related_concepts.extend(r["name"] for r in related)

        distractor_hint = ""
        if related_concepts:
            distractor_hint = (
                f"\nFor MCQ distractors, use these related concepts to create "
                f"plausible wrong answers: {', '.join(set(related_concepts)[:10])}"
            )

        prompt = (
            f"Generate exactly {count} quiz questions based on the following content.\n\n"
            f"Content:\n{shorts_content}\n\n"
            f"Question types to use: {type_names}\n"
            f"Difficulty should vary from 0.3 (easy) to 0.9 (hard).\n"
            f"{distractor_hint}\n\n"
            f"For MCQ: provide exactly 4 options including the correct answer.\n"
            f"For true/false (tf): provide ['True', 'False'] as options.\n"
            f"For fill_blank: include a blank (___) in the question text.\n"
            f"For short_answer: no options needed.\n"
            f"Always provide an explanation for the correct answer."
        )

        try:
            result = await self._llm.generate_structured(
                prompt,
                _GeneratedQuestions,
                system="You are an expert educator creating assessment questions. Be accurate and pedagogically sound.",
                temperature=0.5,
            )

            questions: list[QuizQuestion] = []
            for gq in result.questions[:count]:
                # Validate question type
                try:
                    q_type = QuizQuestionType(gq.type)
                except ValueError:
                    q_type = QuizQuestionType.MCQ

                questions.append(QuizQuestion(
                    id=str(uuid.uuid4()),
                    text=gq.text,
                    type=q_type,
                    options=gq.options,
                    correct_answer=gq.correct_answer,
                    explanation=gq.explanation,
                    difficulty=max(0.0, min(1.0, gq.difficulty)),
                ))

            return questions

        except Exception:
            logger.exception("Quiz generation failed")
            return []

    async def _gather_content(
        self,
        user_id: str,
        short_ids: list[str] | None,
        topic: str | None,
    ) -> str:
        """Gather short content for question generation."""
        shorts = []

        if short_ids:
            for sid in short_ids:
                short = await self._short_repo.get(user_id, sid)
                if short:
                    shorts.append(short)
        elif topic:
            shorts = await self._short_repo.get_by_topic(user_id, topic, limit=10)

        if not shorts:
            return ""

        parts: list[str] = []
        for s in shorts[:10]:
            parts.append(f"## {s.title}\n{s.content}")

        return "\n\n".join(parts)
