"""Source polling Celery tasks (SYS-02).

Polls active sources for health checks and dispatches per-source checks.
Tasks are thin wrappers — uses SourceService for business logic.
All tasks are idempotent (safe to retry).
"""
from __future__ import annotations

import asyncio
import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def poll_active_sources(self) -> dict:
    """Poll all active sources for health status.

    Iterates all users, fetches their active sources, and dispatches
    individual poll_source tasks for each.
    """
    logger.info("Polling active sources")

    try:
        result = asyncio.run(_run_poll_active_sources())
        logger.info(
            "Source polling dispatched: %d sources across %d users",
            result["sources_dispatched"],
            result["users_checked"],
        )
        return {"status": "completed", **result}

    except Exception as exc:
        logger.error("Source polling failed: %s", exc)
        delay = 60 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def poll_source(self, user_id: str, source_id: str) -> dict:
    """Poll a specific source — check health and update status."""
    logger.info("Polling source %s for user %s", source_id, user_id)

    try:
        result = asyncio.run(_run_poll_source(user_id, source_id))
        logger.info("Source poll completed: %s → %s", source_id, result["source_status"])
        return {"status": "completed", "source_id": source_id, **result}

    except Exception as exc:
        logger.error("Source poll failed for %s: %s", source_id, exc)
        delay = 30 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


async def _run_poll_active_sources() -> dict:
    """Get all users, find active sources, dispatch individual polls."""
    from app.dependencies import get_firestore_db, get_source_repository  # noqa: PLC0415

    db = get_firestore_db()
    source_repo = get_source_repository()

    users_checked = 0
    sources_dispatched = 0

    user_docs = await asyncio.to_thread(lambda: list(db.collection("users").stream()))
    for user_doc in user_docs:
        user_id = user_doc.id
        users_checked += 1

        active_sources = await source_repo.get_active(user_id)
        for source in active_sources:
            poll_source.delay(user_id, source.id)
            sources_dispatched += 1

    return {
        "users_checked": users_checked,
        "sources_dispatched": sources_dispatched,
    }


async def _run_poll_source(user_id: str, source_id: str) -> dict:
    """Check health for a single source and update its stats."""
    from app.dependencies import get_source_service  # noqa: PLC0415

    source_service = get_source_service()
    health_result = await source_service.check_health(user_id, source_id)

    return {
        "health_score": health_result["healthScore"],
        "source_status": health_result["status"],
        "error": health_result.get("error"),
    }
