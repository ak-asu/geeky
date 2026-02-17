"""Unit tests for scheduled periodic Celery tasks."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

# Patch target for Firestore
_P_FIRESTORE = "app.dependencies.get_firestore_db"


def _make_user_doc(doc_id, last_active_date, current_streak=3):
    """Create a mock Firestore user document."""
    doc = MagicMock()
    doc.id = doc_id
    doc.to_dict.return_value = {
        "streak": {
            "current": current_streak,
            "lastActiveDate": last_active_date,
            "weeklyActivity": [True] * 7,
        },
    }
    return doc


def _make_concept_doc(doc_id, short_ids=None, p_known=0.0):
    """Create a mock Firestore concept document."""
    doc = MagicMock()
    doc.id = doc_id
    doc.to_dict.return_value = {
        "shortIds": short_ids or [],
        "bktParams": {"pKnown": p_known},
    }
    return doc


def _make_chunk_doc(doc_id, note_id):
    """Create a mock Firestore chunk document."""
    doc = MagicMock()
    doc.id = doc_id
    doc.to_dict.return_value = {"noteId": note_id}
    return doc


def _make_short_doc(doc_id, chunk_ids):
    """Create a mock Firestore short document."""
    doc = MagicMock()
    doc.id = doc_id
    doc.to_dict.return_value = {"chunkIds": chunk_ids}
    return doc


def _make_note_doc(doc_id):
    """Create a mock Firestore note document."""
    doc = MagicMock()
    doc.id = doc_id
    return doc


class TestCalculateDailyStreaks:
    @patch(_P_FIRESTORE)
    def test_resets_inactive_user_streak(self, mock_db_fn):
        """Should reset streak for user who missed a day."""
        user = _make_user_doc("user1", "2026-02-12")
        mock_doc_ref = MagicMock()

        db = MagicMock()
        users_ref = MagicMock()
        users_ref.stream.return_value = [user]
        users_ref.document.return_value = mock_doc_ref
        db.collection.return_value = users_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import calculate_daily_streaks

        result = calculate_daily_streaks()

        assert result["reset_count"] == 1
        mock_doc_ref.update.assert_called_once()
        update_data = mock_doc_ref.update.call_args[0][0]
        assert update_data["streak.current"] == 0

    @patch(_P_FIRESTORE)
    def test_keeps_active_user_streak(self, mock_db_fn):
        """Should not reset streak for user active today."""
        from datetime import datetime, timezone

        today = datetime.now(timezone.utc).date().isoformat()
        user = _make_user_doc("user1", today)

        db = MagicMock()
        users_ref = MagicMock()
        users_ref.stream.return_value = [user]
        db.collection.return_value = users_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import calculate_daily_streaks

        result = calculate_daily_streaks()

        assert result["reset_count"] == 0

    @patch(_P_FIRESTORE)
    def test_no_users(self, mock_db_fn):
        """Should handle empty user list."""
        db = MagicMock()
        db.collection.return_value.stream.return_value = []
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import calculate_daily_streaks

        result = calculate_daily_streaks()

        assert result["reset_count"] == 0


class TestCleanupOrphanedContent:
    @patch(_P_FIRESTORE)
    def test_deletes_orphaned_chunks(self, mock_db_fn):
        """Should delete chunks whose parent note no longer exists."""
        user = MagicMock()
        user.id = "user1"
        user_ref = MagicMock()

        notes_col = MagicMock()
        notes_col.stream.return_value = [_make_note_doc("n1")]

        chunks_col = MagicMock()
        chunks_col.stream.return_value = [
            _make_chunk_doc("c1", "n1"),
            _make_chunk_doc("c2", "n2"),  # orphaned
        ]
        chunk_doc_ref = MagicMock()
        chunks_col.document.return_value = chunk_doc_ref

        shorts_col = MagicMock()
        shorts_col.stream.return_value = []

        user_ref.collection.side_effect = lambda name: {
            "notes": notes_col,
            "chunks": chunks_col,
            "shorts": shorts_col,
        }[name]

        db = MagicMock()
        db.collection.return_value.stream.return_value = [user]
        db.collection.return_value.document.return_value = user_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import cleanup_orphaned_content

        result = cleanup_orphaned_content()

        assert result["orphaned_chunks"] == 1
        assert result["orphaned_shorts"] == 0

    @patch(_P_FIRESTORE)
    def test_deletes_orphaned_shorts(self, mock_db_fn):
        """Should delete shorts with no valid chunk references."""
        user = MagicMock()
        user.id = "user1"
        user_ref = MagicMock()

        notes_col = MagicMock()
        notes_col.stream.return_value = [_make_note_doc("n1")]

        chunks_col = MagicMock()
        chunks_col.stream.return_value = [_make_chunk_doc("c1", "n1")]
        chunks_col.document.return_value = MagicMock()

        shorts_col = MagicMock()
        shorts_col.stream.return_value = [
            _make_short_doc("s1", ["c1"]),      # valid
            _make_short_doc("s2", ["c999"]),     # orphaned
        ]
        short_doc_ref = MagicMock()
        shorts_col.document.return_value = short_doc_ref

        user_ref.collection.side_effect = lambda name: {
            "notes": notes_col,
            "chunks": chunks_col,
            "shorts": shorts_col,
        }[name]

        db = MagicMock()
        db.collection.return_value.stream.return_value = [user]
        db.collection.return_value.document.return_value = user_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import cleanup_orphaned_content

        result = cleanup_orphaned_content()

        assert result["orphaned_shorts"] == 1

    @patch(_P_FIRESTORE)
    def test_deletes_shorts_with_no_chunk_ids(self, mock_db_fn):
        """Should delete shorts that have empty chunkIds."""
        user = MagicMock()
        user.id = "user1"
        user_ref = MagicMock()

        notes_col = MagicMock()
        notes_col.stream.return_value = []

        chunks_col = MagicMock()
        chunks_col.stream.return_value = []
        chunks_col.document.return_value = MagicMock()

        shorts_col = MagicMock()
        shorts_col.stream.return_value = [_make_short_doc("s1", [])]
        short_doc_ref = MagicMock()
        shorts_col.document.return_value = short_doc_ref

        user_ref.collection.side_effect = lambda name: {
            "notes": notes_col,
            "chunks": chunks_col,
            "shorts": shorts_col,
        }[name]

        db = MagicMock()
        db.collection.return_value.stream.return_value = [user]
        db.collection.return_value.document.return_value = user_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import cleanup_orphaned_content

        result = cleanup_orphaned_content()

        assert result["orphaned_shorts"] == 1

    @patch(_P_FIRESTORE)
    def test_no_orphans(self, mock_db_fn):
        """Should report zero when nothing is orphaned."""
        user = MagicMock()
        user.id = "user1"
        user_ref = MagicMock()

        notes_col = MagicMock()
        notes_col.stream.return_value = [_make_note_doc("n1")]

        chunks_col = MagicMock()
        chunks_col.stream.return_value = [_make_chunk_doc("c1", "n1")]
        chunks_col.document.return_value = MagicMock()

        shorts_col = MagicMock()
        shorts_col.stream.return_value = [_make_short_doc("s1", ["c1"])]
        shorts_col.document.return_value = MagicMock()

        user_ref.collection.side_effect = lambda name: {
            "notes": notes_col,
            "chunks": chunks_col,
            "shorts": shorts_col,
        }[name]

        db = MagicMock()
        db.collection.return_value.stream.return_value = [user]
        db.collection.return_value.document.return_value = user_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import cleanup_orphaned_content

        result = cleanup_orphaned_content()

        assert result["orphaned_chunks"] == 0
        assert result["orphaned_shorts"] == 0


class TestUpdateConceptInventories:
    @patch(_P_FIRESTORE)
    def test_updates_importance_and_mastery(self, mock_db_fn):
        """Should compute importance from short count and mastery from p_known."""
        user = MagicMock()
        user.id = "user1"
        user_ref = MagicMock()

        concepts_col = MagicMock()
        concept_doc_ref = MagicMock()
        concepts_col.stream.return_value = [
            _make_concept_doc("c1", short_ids=["s1", "s2", "s3"], p_known=0.95),
            _make_concept_doc("c2", short_ids=["s1"], p_known=0.3),
        ]
        concepts_col.document.return_value = concept_doc_ref

        user_ref.collection.return_value = concepts_col

        db = MagicMock()
        db.collection.return_value.stream.return_value = [user]
        db.collection.return_value.document.return_value = user_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import update_concept_inventories

        result = update_concept_inventories()

        assert result["updated_count"] == 2
        assert concept_doc_ref.update.call_count == 2

    @patch(_P_FIRESTORE)
    def test_mastery_classification(self, mock_db_fn):
        """Should classify mastery levels correctly."""
        user = MagicMock()
        user.id = "user1"
        user_ref = MagicMock()

        concepts_col = MagicMock()
        concept_doc_ref = MagicMock()
        concepts_col.stream.return_value = [
            _make_concept_doc("c1", p_known=0.95),
        ]
        concepts_col.document.return_value = concept_doc_ref

        user_ref.collection.return_value = concepts_col

        db = MagicMock()
        db.collection.return_value.stream.return_value = [user]
        db.collection.return_value.document.return_value = user_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import update_concept_inventories

        update_concept_inventories()

        update_data = concept_doc_ref.update.call_args[0][0]
        assert update_data["masteryState"] == "mastered"

    @patch(_P_FIRESTORE)
    def test_no_concepts(self, mock_db_fn):
        """Should handle users with no concepts."""
        user = MagicMock()
        user.id = "user1"
        user_ref = MagicMock()

        concepts_col = MagicMock()
        concepts_col.stream.return_value = []
        user_ref.collection.return_value = concepts_col

        db = MagicMock()
        db.collection.return_value.stream.return_value = [user]
        db.collection.return_value.document.return_value = user_ref
        mock_db_fn.return_value = db

        from app.workers.scheduled_tasks import update_concept_inventories

        result = update_concept_inventories()

        assert result["updated_count"] == 0
