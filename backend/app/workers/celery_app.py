"""Celery application configuration.

Configures the Celery app with Redis broker, task discovery,
serialization settings, and beat schedule for periodic tasks.
"""

from __future__ import annotations

from celery import Celery
from celery.schedules import crontab

from app.config import get_settings

settings = get_settings()

celery_app = Celery(
    "geeky",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=[
        "app.workers.pipeline_tasks",
        "app.workers.kg_tasks",
        "app.workers.recommendation_tasks",
        "app.workers.quiz_tasks",
        "app.workers.source_tasks",
        "app.workers.lifecycle_tasks",
        "app.workers.scheduled_tasks",
    ],
)

celery_app.conf.update(
    # Serialization
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",

    # Timezone
    timezone="UTC",
    enable_utc=True,

    # Task behavior
    task_track_started=True,
    task_acks_late=True,  # Acknowledge after completion (for reliability)
    worker_prefetch_multiplier=1,  # One task at a time per worker

    # Worker lifecycle — prevent memory leaks from long-running workers
    worker_max_tasks_per_child=100,

    # Global time limits — override per-task as needed
    # Soft: task receives SoftTimeLimitExceeded, can clean up
    # Hard: worker process is killed after this time
    task_soft_time_limit=300,   # 5 min graceful
    task_time_limit=600,        # 10 min hard kill

    # Reliability — re-queue if worker dies during execution
    task_reject_on_worker_lost=True,

    # Retry defaults
    task_default_retry_delay=30,  # 30 seconds
    task_max_retries=3,

    # Result expiry
    result_expires=3600,  # 1 hour

    # Beat schedule — periodic tasks
    beat_schedule={
        # Daily streak calculation at midnight UTC
        "calculate-daily-streaks": {
            "task": "app.workers.scheduled_tasks.calculate_daily_streaks",
            "schedule": crontab(hour=0, minute=5),
        },
        # Source polling every hour
        "poll-active-sources": {
            "task": "app.workers.source_tasks.poll_active_sources",
            "schedule": crontab(minute=0),
        },
        # Orphan cleanup daily at 3 AM UTC
        "cleanup-orphaned-content": {
            "task": "app.workers.scheduled_tasks.cleanup_orphaned_content",
            "schedule": crontab(hour=3, minute=0),
        },
        # Concept inventory update daily at 4 AM UTC
        "update-concept-inventories": {
            "task": "app.workers.scheduled_tasks.update_concept_inventories",
            "schedule": crontab(hour=4, minute=0),
        },
    },
)
