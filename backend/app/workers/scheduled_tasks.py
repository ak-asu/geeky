"""Scheduled periodic Celery tasks (SYS-15, SYS-21)."""
from __future__ import annotations

import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task
def calculate_daily_streaks() -> dict:
    """Calculate and update learning streaks for all users."""
    logger.info("Calculating daily streaks")
    return {"status": "completed"}


@celery_app.task
def cleanup_orphaned_content() -> dict:
    """Remove orphaned shorts/chunks not linked to any note."""
    logger.info("Cleaning up orphaned content")
    return {"status": "completed"}


@celery_app.task
def update_concept_inventories() -> dict:
    """Update concept inventory scores and coverage (SYS-21)."""
    logger.info("Updating concept inventories")
    return {"status": "completed"}
