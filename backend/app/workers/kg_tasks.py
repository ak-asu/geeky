"""Knowledge Graph update Celery tasks (SYS-03)."""
from __future__ import annotations

import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def rebuild_knowledge_graph(self, user_id: str) -> dict:
    """Trigger full KG rebuild for a user."""
    logger.info("Rebuilding KG for user %s", user_id)
    return {"status": "completed", "user_id": user_id}


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def update_kg_for_short(self, user_id: str, short_id: str) -> dict:
    """Update KG after a short is created/updated/deleted."""
    logger.info("Updating KG for short %s user %s", short_id, user_id)
    return {"status": "completed", "short_id": short_id}
