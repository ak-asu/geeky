"""Quiz generation Celery tasks (SYS-12)."""
from __future__ import annotations

import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def generate_quiz_for_short(self, user_id: str, short_id: str) -> dict:
    """Generate quiz questions for a short."""
    logger.info("Generating quiz for short %s user %s", short_id, user_id)
    return {"status": "completed", "short_id": short_id}
