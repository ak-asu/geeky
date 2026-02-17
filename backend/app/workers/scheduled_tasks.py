"""Scheduled periodic Celery tasks (SYS-15, SYS-21).

These tasks run on beat schedules and perform maintenance operations.
All tasks are idempotent (safe to retry).
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

    Runs daily at 3 AM UTC. For each user:
    1. Collects all existing note IDs
    2. Finds chunks whose parent noteId no longer exists → deletes them
    3. Collects remaining valid chunk IDs
    4. Finds shorts whose chunkIds have zero intersection with valid chunks → deletes them
    """
    logger.info("Cleaning up orphaned content")

    from app.dependencies import get_firestore_db  # noqa: PLC0415

    db = get_firestore_db()
    orphaned_chunks = 0
    orphaned_shorts = 0

    for user_doc in db.collection("users").stream():
        user_id = user_doc.id
        user_ref = db.collection("users").document(user_id)

        # 1. Get all existing note IDs
        note_ids = set()
        for note in user_ref.collection("notes").stream():
            note_ids.add(note.id)

        # 2. Find and delete orphaned chunks (noteId not in note_ids)
        valid_chunk_ids = set()
        for chunk in user_ref.collection("chunks").stream():
            chunk_data = chunk.to_dict()
            chunk_note_id = chunk_data.get("noteId", "")
            if chunk_note_id and chunk_note_id not in note_ids:
                # Orphaned chunk — parent note deleted
                user_ref.collection("chunks").document(chunk.id).delete()
                orphaned_chunks += 1
            else:
                valid_chunk_ids.add(chunk.id)

        # 3. Find and delete orphaned shorts (no valid chunk references)
        for short in user_ref.collection("shorts").stream():
            short_data = short.to_dict()
            chunk_ids = short_data.get("chunkIds", [])

            if not chunk_ids:
                # Short with no chunk references is orphaned
                user_ref.collection("shorts").document(short.id).delete()
                orphaned_shorts += 1
            elif not set(chunk_ids) & valid_chunk_ids:
                # None of this short's chunks exist anymore
                user_ref.collection("shorts").document(short.id).delete()
                orphaned_shorts += 1

    logger.info(
        "Cleaned %d orphaned chunks, %d orphaned shorts",
        orphaned_chunks, orphaned_shorts,
    )
    return {
        "status": "completed",
        "orphaned_chunks": orphaned_chunks,
        "orphaned_shorts": orphaned_shorts,
    }


@celery_app.task
def update_concept_inventories() -> dict:
    """Update concept inventory scores and coverage (SYS-21).

    Runs daily at 4 AM UTC. For each user:
    1. Iterates all concepts
    2. Computes importance from number of linked shorts
    3. Updates mastery classification from BKT p_known
    """
    logger.info("Updating concept inventories")

    from app.dependencies import get_firestore_db  # noqa: PLC0415

    db = get_firestore_db()
    updated_count = 0

    for user_doc in db.collection("users").stream():
        user_id = user_doc.id
        user_ref = db.collection("users").document(user_id)

        for concept_doc in user_ref.collection("concepts").stream():
            concept_data = concept_doc.to_dict()

            # Compute importance from linked shorts count
            short_ids = concept_data.get("shortIds", [])
            importance = min(1.0, len(short_ids) / 10.0)  # Normalize: 10+ shorts = max importance

            # Get current mastery from BKT params
            bkt_params = concept_data.get("bktParams", {})
            p_known = bkt_params.get("pKnown", 0.0)

            # Classify mastery level
            if p_known >= 0.9:
                mastery_state = "mastered"
            elif p_known >= 0.7:
                mastery_state = "proficient"
            elif p_known >= 0.4:
                mastery_state = "developing"
            elif p_known > 0.0:
                mastery_state = "novice"
            else:
                mastery_state = "unknown"

            user_ref.collection("concepts").document(concept_doc.id).update({
                "importance": importance,
                "masteryState": mastery_state,
            })
            updated_count += 1

    logger.info("Updated %d concept inventories", updated_count)
    return {"status": "completed", "updated_count": updated_count}
