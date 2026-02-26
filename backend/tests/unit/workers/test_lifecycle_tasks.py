"""Unit tests for lifecycle cascade Celery tasks."""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# Patch targets — lazy imports from app.dependencies inside _run_cascade_delete
_P_CHUNK_REPO = "app.dependencies.get_chunk_repository"
_P_SHORT_REPO = "app.dependencies.get_short_repository"
_P_VECTOR_STORE = "app.dependencies.get_vector_store"


@dataclass
class _MockChunk:
    id: str = "chunk1"
    note_id: str = "note1"


@dataclass
class _MockShort:
    id: str = "short1"
    chunk_ids: list = field(default_factory=lambda: ["chunk1"])
    citations: list = field(default_factory=list)


class TestCascadeNoteDelete:
    @patch(_P_VECTOR_STORE)
    @patch(_P_SHORT_REPO)
    @patch(_P_CHUNK_REPO)
    def test_deletes_chunks_shorts_and_embeddings(self, mock_chunk_fn, mock_short_fn, mock_vector_fn):
        """Should cascade delete: chunks → orphaned shorts → embeddings."""
        chunk_repo = AsyncMock()
        chunk_repo.get_by_note = AsyncMock(return_value=[
            _MockChunk(id="c1"), _MockChunk(id="c2"),
        ])
        chunk_repo.delete_by_note = AsyncMock(return_value=2)
        mock_chunk_fn.return_value = chunk_repo

        short_repo = AsyncMock()
        short_repo.get_by_chunk_ids = AsyncMock(return_value=[
            _MockShort(id="s1", chunk_ids=["c1", "c2"]),
        ])
        short_repo.delete = AsyncMock()
        mock_short_fn.return_value = short_repo

        vector_store = AsyncMock()
        vector_store.delete = AsyncMock()
        mock_vector_fn.return_value = vector_store

        from app.workers.lifecycle_tasks import cascade_note_delete

        result = cascade_note_delete("user1", "note1")

        assert result["status"] == "completed"
        assert result["chunks_deleted"] == 2
        assert result["shorts_deleted"] == 1
        assert result["embeddings_deleted"] == 2
        vector_store.delete.assert_called_once()

    @patch(_P_VECTOR_STORE)
    @patch(_P_SHORT_REPO)
    @patch(_P_CHUNK_REPO)
    def test_keeps_shorts_with_other_chunk_refs(self, mock_chunk_fn, mock_short_fn, mock_vector_fn):
        """Shorts referencing chunks from other notes should survive."""
        chunk_repo = AsyncMock()
        chunk_repo.get_by_note = AsyncMock(return_value=[_MockChunk(id="c1")])
        chunk_repo.delete_by_note = AsyncMock(return_value=1)
        mock_chunk_fn.return_value = chunk_repo

        short_repo = AsyncMock()
        short_repo.get_by_chunk_ids = AsyncMock(return_value=[
            _MockShort(id="s1", chunk_ids=["c1", "c99"]),
        ])
        short_repo.update = AsyncMock()
        short_repo.delete = AsyncMock()
        mock_short_fn.return_value = short_repo

        vector_store = AsyncMock()
        vector_store.delete = AsyncMock()
        mock_vector_fn.return_value = vector_store

        from app.workers.lifecycle_tasks import cascade_note_delete

        result = cascade_note_delete("user1", "note1")

        assert result["shorts_deleted"] == 0
        short_repo.update.assert_called_once()
        short_repo.delete.assert_not_called()

    @patch(_P_VECTOR_STORE)
    @patch(_P_SHORT_REPO)
    @patch(_P_CHUNK_REPO)
    def test_no_chunks(self, mock_chunk_fn, mock_short_fn, mock_vector_fn):
        """Should handle note with no chunks gracefully."""
        chunk_repo = AsyncMock()
        chunk_repo.get_by_note = AsyncMock(return_value=[])
        chunk_repo.delete_by_note = AsyncMock(return_value=0)
        mock_chunk_fn.return_value = chunk_repo

        short_repo = AsyncMock()
        short_repo.get_by_chunk_ids = AsyncMock(return_value=[])
        mock_short_fn.return_value = short_repo

        vector_store = AsyncMock()
        mock_vector_fn.return_value = vector_store

        from app.workers.lifecycle_tasks import cascade_note_delete

        result = cascade_note_delete("user1", "note1")

        assert result["chunks_deleted"] == 0
        assert result["shorts_deleted"] == 0
        assert result["embeddings_deleted"] == 0
        vector_store.delete.assert_not_called()


class TestCascadeNoteUpdate:
    @patch("app.workers.pipeline_tasks._run_pipeline", new_callable=AsyncMock)
    @patch(_P_VECTOR_STORE)
    @patch(_P_SHORT_REPO)
    @patch(_P_CHUNK_REPO)
    def test_deletes_old_content_then_re_pipelines(
        self, mock_chunk_fn, mock_short_fn, mock_vector_fn, mock_pipeline
    ):
        """Should delete old derived content then re-run pipeline."""
        chunk_repo = AsyncMock()
        chunk_repo.get_by_note = AsyncMock(return_value=[_MockChunk(id="c1")])
        chunk_repo.delete_by_note = AsyncMock(return_value=1)
        mock_chunk_fn.return_value = chunk_repo

        short_repo = AsyncMock()
        short_repo.get_by_chunk_ids = AsyncMock(return_value=[
            _MockShort(id="s1", chunk_ids=["c1"]),
        ])
        short_repo.delete = AsyncMock()
        mock_short_fn.return_value = short_repo

        vector_store = AsyncMock()
        vector_store.delete = AsyncMock()
        mock_vector_fn.return_value = vector_store

        mock_pipeline.return_value = {"chunks_created": 3, "shorts_created": 2}

        from app.workers.lifecycle_tasks import cascade_note_update

        result = cascade_note_update("user1", "note1", "task1")

        assert result["status"] == "completed"
        mock_pipeline.assert_called_once()
