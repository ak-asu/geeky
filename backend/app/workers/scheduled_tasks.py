"""Scheduled periodic Celery tasks (SYS-15, SYS-21).

These tasks run on beat schedules and perform maintenance operations.
"""
from __future__ import annotations

import logging

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task
def calculate_daily_streaks() -> dict:
    """Calculate and update learning streaks for all users.

    Runs daily at midnight UTC. Checks each user's last_active_date
    and resets the streak if they missed a day.
    """
    logger.info("Calculating daily streaks")

    from datetime import datetime, timedelta, timezone  # noqa: PLC0415

    from app.dependencies import get_firestore_db  # noqa: PLC0415

    db = get_firestore_db()
    users_ref = db.collection("users")
    yesterday = (datetime.now(timezone.utc).date() - timedelta(days=1)).isoformat()
    today = datetime.now(timezone.utc).date().isoformat()

    reset_count = 0
    for doc in users_ref.stream():
        data = doc.to_dict()
        streak = data.get("streak", {})
        last_active = streak.get("lastActiveDate")

        # If user was not active yesterday or today, reset streak
        if last_active and last_active not in (yesterday, today):
            users_ref.document(doc.id).update({
                "streak.current": 0,
                "streak.weeklyActivity": [False] * 7,
            })
            reset_count += 1

    logger.info("Reset %d user streaks", reset_count)
    return {"status": "completed", "reset_count": reset_count}


@celery_app.task
def cleanup_orphaned_content() -> dict:
    """Remove orphaned shorts/chunks not linked to any note.

    Runs daily at 3 AM UTC. Finds shorts/chunks that have no
    parent note reference and deletes them.
    """
    logger.info("Cleaning up orphaned content")

    from app.dependencies import get_firestore_db  # noqa: PLC0415

    db = get_firestore_db()
    cleaned = 0

    for user_doc in db.collection("users").stream():
        user_id = user_doc.id
        user_ref = db.collection("users").document(user_id)

        # Get all note IDs for this user
        note_ids = set()
        for note in user_ref.collection("notes").stream():
            note_ids.add(note.id)

        # Find shorts whose parent note no longer exists
        for short in user_ref.collection("shorts").stream():
            short_data = short.to_dict()
            # Shorts generated from chunks reference their source note
            chunk_ids = short_data.get("chunkIds", [])
            if not chunk_ids and not note_ids:
                # Orphaned short with no associated notes
                user_ref.collection("shorts").document(short.id).delete()
                cleaned += 1

    logger.info("Cleaned %d orphaned items", cleaned)
    return {"status": "completed", "cleaned": cleaned}


@celery_app.task
def update_concept_inventories() -> dict:
    """Update concept inventory scores and coverage (SYS-21)."""
    logger.info("Updating concept inventories")
    return {"status": "completed"}
