"""Lifecycle cascade Celery tasks (SYS-08, SYS-09).

Tasks are thin wrappers — business logic for cascade operations.
All tasks are idempotent (safe to retry).
"""

from __future__ import annotations

import asyncio
import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def cascade_note_delete(self, user_id: str, note_id: str) -> dict:
    """Cascade delete: chunks → orphaned shorts → vector embeddings (LM-02, LM-03).

    Deletes all chunks, shorts, and vector embeddings associated with the note.
    """
    logger.info("Cascading delete for note %s user %s", note_id, user_id)

    try:
        result = asyncio.run(_run_cascade_delete(user_id, note_id))
        logger.info("Cascade delete completed for note %s: %s", note_id, result)
        return {"status": "completed", "note_id": note_id, **result}

    except Exception as exc:
        logger.error("Cascade delete failed for note %s: %s", note_id, exc)
        delay = 30 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def cascade_note_update(self, user_id: str, note_id: str, task_id: str) -> dict:
    """Re-process note after edit: delete old derived content, re-run pipeline (LM-01)."""
    logger.info("Cascading update for note %s user %s (task=%s)", note_id, user_id, task_id)

    try:
        result = asyncio.run(_run_cascade_update(user_id, note_id, task_id))
        logger.info("Cascade update completed for note %s: %s", note_id, result)
        return {"status": "completed", "note_id": note_id, **result}

    except Exception as exc:
        logger.error("Cascade update failed for note %s: %s", note_id, exc)
        delay = 30 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


async def _run_cascade_delete(user_id: str, note_id: str) -> dict:
    """Delete all derived content for a note: chunks, shorts, vector embeddings."""
    from app.dependencies import (  # noqa: PLC0415
        get_chunk_repository,
        get_short_repository,
        get_vector_store,
    )

    chunk_repo = get_chunk_repository()
    short_repo = get_short_repository()
    vector_store = get_vector_store()

    # Get all chunks for this note
    chunks = await chunk_repo.get_by_note(user_id, note_id)
    chunk_ids = [c.id for c in chunks]

    # Delete vector embeddings
    if chunk_ids:
        await vector_store.delete(ids=chunk_ids, user_id=user_id)

    # Get shorts that cite this note
    shorts = await short_repo.get_by_chunk_ids(user_id, chunk_ids)

    # Delete orphaned shorts (only cite this note's chunks)
    shorts_deleted = 0
    for short in shorts:
        other_chunk_refs = [cid for cid in short.chunk_ids if cid not in chunk_ids]
        if not other_chunk_refs:
            # Orphaned — delete it
            await short_repo.delete(user_id, short.id)
            shorts_deleted += 1
        else:
            # Surviving — remove citations to deleted chunks
            remaining_chunk_ids = [cid for cid in short.chunk_ids if cid not in chunk_ids]
            remaining_citations = [
                c.model_dump(by_alias=True)
                for c in short.citations
                if c.chunk_id not in chunk_ids
            ]
            await short_repo.update(user_id, short.id, {
                "chunkIds": remaining_chunk_ids,
                "citations": remaining_citations,
            })

    # Delete chunk documents from Firestore
    chunks_deleted = await chunk_repo.delete_by_note(user_id, note_id)

    return {
        "chunks_deleted": chunks_deleted,
        "shorts_deleted": shorts_deleted,
        "embeddings_deleted": len(chunk_ids),
    }


async def _run_cascade_update(user_id: str, note_id: str, task_id: str) -> dict:
    """Delete old derived content then re-run the pipeline in a single event loop."""
    await _run_cascade_delete(user_id, note_id)

    from app.workers.pipeline_tasks import _run_pipeline  # noqa: PLC0415

    return await _run_pipeline(user_id, note_id, task_id)
