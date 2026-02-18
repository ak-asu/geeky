"""Quiz grader service.

Grades quiz answers, persists the attempt, and updates BKT concept mastery.
Extracted from the route layer to keep routes thin (as per architecture rules).
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from app.exceptions import ConceptNotFoundError
from app.models.quiz import QuizGradeRequest
from app.models.quiz_attempt import QuizAttemptAnswer, QuizAttemptDocument

logger = logging.getLogger(__name__)


class QuizGrader:
    """Grades quiz answers, persists the attempt, and updates BKT concept mastery.

    Args:
        quiz_attempt_repo: Repository for persisting quiz attempts.
        bkt_tracker: BKT mastery tracker to update per-concept mastery.
        short_repo: Short repository to look up concept IDs for BKT updates.
    """

    def __init__(self, *, quiz_attempt_repo: Any, bkt_tracker: Any, short_repo: Any) -> None:
        self._quiz_attempt_repo = quiz_attempt_repo
        self._bkt_tracker = bkt_tracker
        self._short_repo = short_repo

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
            is_correct = qa.answer.strip().lower() == qa.correct_answer.strip().lower()
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
