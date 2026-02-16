"""Knowledge Graph Celery tasks (SYS-03, KG-01, KG-06).

Tasks are thin wrappers — business logic lives in GraphBuilder.
All tasks are idempotent (safe to retry).
"""
from __future__ import annotations

import asyncio
import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def rebuild_knowledge_graph(self, user_id: str) -> dict:
    """Full KG rebuild for a user — re-process all shorts."""
    logger.info(
        "Rebuilding KG for user %s (attempt=%d)",
        user_id, self.request.retries,
    )
    try:
        result = asyncio.run(_run_rebuild(user_id))
        logger.info("KG rebuild completed for user %s: %s", user_id, result)
        return {"status": "completed", "user_id": user_id, **result}
    except Exception as exc:
        logger.error("KG rebuild failed for user %s: %s", user_id, exc)
        delay = 30 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def update_kg_for_short(self, user_id: str, short_id: str) -> dict:
    """Incrementally update KG after a short is created/updated (KG-06)."""
    logger.info(
        "Updating KG for short %s user %s (attempt=%d)",
        short_id, user_id, self.request.retries,
    )
    try:
        result = asyncio.run(_run_update_for_short(user_id, short_id))
        logger.info("KG update completed for short %s: %s", short_id, result)
        return {"status": "completed", "short_id": short_id, **result}
    except Exception as exc:
        logger.error("KG update failed for short %s: %s", short_id, exc)
        delay = 30 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


@celery_app.task(bind=True, max_retries=2, default_retry_delay=60)
def ensure_review_states(self, user_id: str, short_ids: list[str]) -> dict:
    """Create ReviewState documents for newly created shorts."""
    logger.info(
        "Ensuring review states for %d shorts, user %s",
        len(short_ids), user_id,
    )
    try:
        result = asyncio.run(_run_ensure_review_states(user_id, short_ids))
        logger.info("Review states created: %s", result)
        return {"status": "completed", **result}
    except Exception as exc:
        logger.error("Review state creation failed: %s", exc)
        delay = 60 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


async def _run_rebuild(user_id: str) -> dict:
    from app.dependencies import get_graph_builder  # noqa: PLC0415
    builder = get_graph_builder()
    return await builder.rebuild_for_user(user_id)


async def _run_update_for_short(user_id: str, short_id: str) -> dict:
    from app.dependencies import get_graph_builder  # noqa: PLC0415
    builder = get_graph_builder()
    return await builder.build_for_short(user_id, short_id)


async def _run_ensure_review_states(user_id: str, short_ids: list[str]) -> dict:
    from app.dependencies import get_review_manager  # noqa: PLC0415
    manager = get_review_manager()
    created = await manager.ensure_review_states(user_id, short_ids)
    return {"created": created}
