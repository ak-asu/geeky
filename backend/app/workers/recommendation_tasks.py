"""Recommendation recalculation Celery tasks (SYS-04)."""
from __future__ import annotations

import asyncio
import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def recalculate_recommendations(self, user_id: str) -> dict:
    """Recalculate recommendation scores for a user.

    Called when user interactions change significantly or
    on explicit refresh request. Runs the full scoring pipeline
    via the FeedRanker.
    """
    logger.info("Recalculating recommendations for user %s", user_id)

    try:
        from app.dependencies import get_feed_ranker  # noqa: PLC0415

        ranker = get_feed_ranker()
        result = asyncio.get_event_loop().run_until_complete(
            ranker.refresh(user_id)
        )

        logger.info(
            "Recommendation recalculation completed for user %s: %d scored",
            user_id,
            result.get("totalScored", 0),
        )
        return {"status": "completed", "user_id": user_id, **result}

    except Exception as exc:
        logger.error(
            "Recommendation recalculation failed for user %s: %s",
            user_id,
            exc,
        )
        raise self.retry(exc=exc)
