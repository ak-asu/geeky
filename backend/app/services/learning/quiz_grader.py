"""Quiz grader service.

Grades quiz answers, persists the attempt, and updates BKT concept mastery.

Grading strategy per question type:
- MCQ, TRUE_FALSE, FILL_BLANK → exact string match (normalised)
- OPEN_ENDED, SHORT_ANSWER    → semantic cosine similarity via EmbeddingProvider
                                 (falls back to exact match if provider unavailable)
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from app.exceptions import ConceptNotFoundError
from app.models.common import QuizQuestionType
from app.models.quiz import QuizAnswer, QuizGradeRequest
from app.models.quiz_attempt import QuizAttemptAnswer, QuizAttemptDocument
from app.utils.math_utils import cosine_similarity

logger = logging.getLogger(__name__)

# Question types that warrant semantic (embedding-based) grading
_SEMANTIC_TYPES = {QuizQuestionType.OPEN_ENDED, QuizQuestionType.SHORT_ANSWER}



class QuizGrader:
    """Grades quiz answers, persists the attempt, and updates BKT concept mastery.

    Args:
        quiz_attempt_repo: Repository for persisting quiz attempts.
        bkt_tracker: BKT mastery tracker to update per-concept mastery.
        short_repo: Short repository to look up concept IDs for BKT updates.
        embedding_provider: Optional EmbeddingProvider for semantic grading of
            open-ended and short-answer questions. When None, falls back to
            normalised exact-match for all question types.
    """

    def __init__(
        self,
        *,
        quiz_attempt_repo: Any,
        bkt_tracker: Any,
        short_repo: Any,
        embedding_provider: Any = None,
    ) -> None:
        self._quiz_attempt_repo = quiz_attempt_repo
        self._bkt_tracker = bkt_tracker
        self._short_repo = short_repo
        self._embedding_provider = embedding_provider

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def grade_and_save(self, user_id: str, body: QuizGradeRequest) -> dict:
        """Grade answers, save QuizAttemptDocument, update BKT mastery.

        Args:
            user_id: The authenticated user.
            body: Quiz grade request with answers and short_ids.

        Returns:
            Dict with attemptId, results, totalQuestions, correctCount, score.
        """
        graded: list[QuizAttemptAnswer] = []
        results: list[dict] = []
        correct_count = 0

        for qa in body.answers:
            is_correct = await self._grade_answer(qa)
            if is_correct:
                correct_count += 1

            graded.append(QuizAttemptAnswer(
                question_id=qa.question_id,
                user_answer=qa.answer,
                correct_answer=qa.correct_answer,
                correct=is_correct,
            ))
            results.append({
                "questionId": qa.question_id,
                "correct": is_correct,
            })

        total = max(len(body.answers), 1)
        score = correct_count / total

        attempt_id = str(uuid.uuid4())
        attempt = QuizAttemptDocument(
            id=attempt_id,
            short_ids=body.short_ids,
            answers=graded,
            total_questions=len(body.answers),
            correct_count=correct_count,
            score=score,
        )
        await self._quiz_attempt_repo.create(user_id, attempt, doc_id=attempt_id)

        # Update BKT mastery for concepts associated with the tested shorts.
        # Use the overall quiz score as the observation signal for each concept.
        if body.short_ids:
            await self._update_bkt_mastery(user_id, body.short_ids, correct=score >= 0.5)

        return {
            "attemptId": attempt_id,
            "results": results,
            "totalQuestions": len(body.answers),
            "correctCount": correct_count,
            "score": score,
        }

    # ------------------------------------------------------------------
    # Private grading helpers
    # ------------------------------------------------------------------

    async def _grade_answer(self, qa: QuizAnswer) -> bool:
        """Dispatch to semantic or exact grading based on question type."""
        if qa.question_type in _SEMANTIC_TYPES and self._embedding_provider is not None:
            return await self._semantic_grade(qa.answer, qa.correct_answer)
        return _exact_match(qa.answer, qa.correct_answer)

    async def _semantic_grade(self, answer: str, correct_answer: str) -> bool:
        """Grade via embedding cosine similarity.

        Falls back to exact match on any error (embedding unavailable, timeout, etc.).
        """
        from app.config import get_settings  # noqa: PLC0415

        try:
            threshold = get_settings().quiz_semantic_threshold
            embeddings = await self._embedding_provider.embed_texts([answer, correct_answer])
            similarity = cosine_similarity(embeddings[0], embeddings[1])
            logger.debug(
                "Semantic quiz grade: similarity=%.3f threshold=%.3f correct=%s",
                similarity, threshold, similarity >= threshold,
            )
            return similarity >= threshold
        except Exception as exc:
            logger.warning("Semantic grading failed, falling back to exact match: %s", exc)
            return _exact_match(answer, correct_answer)

    async def _update_bkt_mastery(
        self, user_id: str, short_ids: list[str], correct: bool
    ) -> None:
        """Update BKT mastery for all concepts linked to the given shorts.

        Silently skips shorts/concepts that cannot be found — BKT updates are
        best-effort and should not block the quiz submission result.

        Args:
            user_id: The authenticated user.
            short_ids: Shorts whose concepts to update.
            correct: True if the user demonstrated mastery (score >= 50%).
        """
        updated_concept_ids: set[str] = set()

        for short_id in short_ids:
            try:
                short = await self._short_repo.get(user_id, short_id)
                if not short or not short.concept_ids:
                    continue

                for concept_id in short.concept_ids:
                    if concept_id in updated_concept_ids:
                        continue  # Avoid duplicate updates for shared concepts
                    try:
                        await self._bkt_tracker.update_bkt(user_id, concept_id, correct)
                        updated_concept_ids.add(concept_id)
                    except ConceptNotFoundError:
                        logger.debug(
                            "Concept %s not found for BKT update (user=%s)", concept_id, user_id
                        )
                    except Exception as exc:
                        logger.warning(
                            "BKT update failed for concept=%s user=%s: %s",
                            concept_id, user_id, exc,
                        )
            except Exception as exc:
                logger.warning(
                    "Failed to fetch short=%s for BKT update user=%s: %s",
                    short_id, user_id, exc,
                )

        if updated_concept_ids:
            logger.debug(
                "BKT mastery updated for %d concepts (user=%s, correct=%s)",
                len(updated_concept_ids), user_id, correct,
            )


# ------------------------------------------------------------------
# Module-level helpers
# ------------------------------------------------------------------

def _exact_match(answer: str, correct_answer: str) -> bool:
    """Normalised exact match: strip whitespace and lowercase."""
    return answer.strip().lower() == correct_answer.strip().lower()
