"""Source polling Celery tasks (SYS-02)."""
from __future__ import annotations

import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def poll_active_sources(self) -> dict:
    """Poll all active sources for new content."""
    logger.info("Polling active sources")
    return {"status": "completed"}


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def poll_source(self, user_id: str, source_id: str) -> dict:
    """Poll a specific source for new content."""
    logger.info("Polling source %s for user %s", source_id, user_id)
    return {"status": "completed", "source_id": source_id}
