"""Recommendation recalculation Celery tasks (SYS-04)."""
from __future__ import annotations

import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def recalculate_recommendations(self, user_id: str) -> dict:
    """Recalculate recommendation scores for a user."""
    logger.info("Recalculating recommendations for user %s", user_id)
    return {"status": "completed", "user_id": user_id}
