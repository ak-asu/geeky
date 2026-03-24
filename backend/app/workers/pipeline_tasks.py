"""Content processing pipeline Celery tasks (SYS-01).

Tasks are thin wrappers — business logic lives in services.
All tasks are idempotent (safe to retry).
"""

from __future__ import annotations

import asyncio
import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=30,
    soft_time_limit=540,  # 9 min graceful (pipeline can take a while for large docs)
    time_limit=600,       # 10 min hard kill
)
def process_note(self, user_id: str, note_id: str, task_id: str) -> dict:
    """Orchestrate the full note processing pipeline.

    Pipeline: extract → chunk → dedup → embed → generate shorts → store.
    Celery tasks run sync — we use asyncio.run() to call async orchestrator.
    """
    logger.info(
        "Processing note %s for user %s (task=%s, attempt=%d)",
        note_id, user_id, task_id, self.request.retries,
    )

    try:
        result = asyncio.run(_run_pipeline(user_id, note_id, task_id))
        logger.info("Pipeline completed for note %s: %s", note_id, result)
        return {"status": "completed", "note_id": note_id, **result}

    except Exception as exc:
        logger.error(
            "Pipeline failed for note %s (attempt %d): %s",
            note_id, self.request.retries, exc,
        )
        delay = 30 * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=delay)


async def _run_pipeline(user_id: str, note_id: str, task_id: str) -> dict:
    """Instantiate orchestrator with all dependencies and run pipeline."""
    from app.config import get_settings  # noqa: PLC0415
    from app.dependencies import (  # noqa: PLC0415
        get_chunk_repository,
        get_document_parser,
        get_embedding_provider,
        get_llm_provider,
        get_ner_extractor,
        get_note_repository,
        get_processing_task_repository,
        get_short_repository,
        get_subscription_service,
        get_vector_store,
    )
    from app.exceptions import PremiumRequiredError  # noqa: PLC0415
    from app.models.common import ProcessingStatus  # noqa: PLC0415
    from app.services.pipeline.orchestrator import PipelineOrchestrator  # noqa: PLC0415

    # Guard: reject the pipeline immediately for free-tier users.
    # Free users can create and store notes but the AI pipeline
    # (embedding + Shorts generation) is a Premium-only feature.
    sub_svc = get_subscription_service()
    try:
        await sub_svc.check_processing_quota(user_id)
    except PremiumRequiredError as exc:
        logger.info(
            "Pipeline skipped for free-tier user %s (note=%s): %s",
            user_id, note_id, exc,
        )
        task_repo = get_processing_task_repository()
        await task_repo.update_status(task_id, ProcessingStatus.FAILED.value, str(exc))
        return {"chunks_created": 0, "shorts_created": 0}

    orchestrator = PipelineOrchestrator(
        document_parser=get_document_parser(),
        embedding_provider=get_embedding_provider(),
        vector_store=get_vector_store(),
        llm_provider=get_llm_provider(),
        note_repo=get_note_repository(),
        chunk_repo=get_chunk_repository(),
        short_repo=get_short_repository(),
        processing_task_repo=get_processing_task_repository(),
        settings=get_settings(),
        ner_extractor=get_ner_extractor(),
    )

    return await orchestrator.process(user_id, note_id, task_id)
