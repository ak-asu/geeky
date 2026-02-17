"""Quiz generation Celery tasks (SYS-12).

Generates quiz questions for shorts using the QuizGenerator service.
Tasks are thin wrappers — business logic lives in services.
All tasks are idempotent (safe to retry).
"""
from __future__ import annotations

import asyncio
import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def generate_quiz_for_short(self, user_id: str, short_id: str) -> dict:
    """Generate quiz questions for a short.

    Uses the QuizGenerator service to create questions from short content,
    then stores them in the quiz repository.
    """
    logger.info(
        "Generating quiz for short %s user %s (attempt=%d)",
        short_id, user_id, self.request.retries,
    )

    try:
        result = asyncio.run(_run_generate_quiz(user_id, short_id))
        logger.info(
            "Quiz generation completed for short %s: %d questions",
            short_id, result["questions_generated"],
        )
        return {"status": "completed", "short_id": short_id, **result}

    except Exception as exc:
        logger.error(
            "Quiz generation failed for short %s (attempt %d): %s",
            short_id, self.request.retries, exc,
        )
        delay = 30 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


async def _run_generate_quiz(user_id: str, short_id: str) -> dict:
    """Generate and store quiz questions for a short."""
    from app.dependencies import get_quiz_generator, get_quiz_repository  # noqa: PLC0415

    generator = get_quiz_generator()
    quiz_repo = get_quiz_repository()

    questions = await generator.generate(
        user_id,
        short_ids=[short_id],
        count=5,
    )

    stored_count = 0
    for question in questions:
        await quiz_repo.create(user_id, question)
        stored_count += 1

    return {
        "questions_generated": len(questions),
        "questions_stored": stored_count,
    }
