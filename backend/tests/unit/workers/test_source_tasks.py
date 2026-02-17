"""Unit tests for source polling Celery tasks."""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# Patch targets — lazy imports from app.dependencies inside async helpers
_P_FIRESTORE = "app.dependencies.get_firestore_db"
_P_SOURCE_REPO = "app.dependencies.get_source_repository"
_P_SOURCE_SERVICE = "app.dependencies.get_source_service"


@dataclass
class _MockSource:
    id: str = "src1"
    url: str = "https://example.com/feed"
    status: str = "active"


class TestPollActiveSources:
    @patch("app.workers.source_tasks.poll_source")
    @patch(_P_SOURCE_REPO)
    @patch(_P_FIRESTORE)
    def test_dispatches_poll_for_each_active_source(self, mock_db_fn, mock_repo_fn, mock_poll_task):
        """poll_active_sources should dispatch poll_source for each active source."""
        user1 = MagicMock()
        user1.id = "user1"
        user2 = MagicMock()
        user2.id = "user2"
        mock_db_fn.return_value.collection.return_value.stream.return_value = [user1, user2]

        source_repo = AsyncMock()
        source_repo.get_active = AsyncMock(side_effect=[
            [_MockSource(id="s1"), _MockSource(id="s2")],
            [_MockSource(id="s3")],
        ])
        mock_repo_fn.return_value = source_repo

        mock_poll_task.delay = MagicMock()

        from app.workers.source_tasks import poll_active_sources

        result = poll_active_sources()

        assert result["status"] == "completed"
        assert result["users_checked"] == 2
        assert result["sources_dispatched"] == 3
        assert mock_poll_task.delay.call_count == 3

    @patch("app.workers.source_tasks.poll_source")
    @patch(_P_SOURCE_REPO)
    @patch(_P_FIRESTORE)
    def test_no_sources(self, mock_db_fn, mock_repo_fn, mock_poll_task):
        """poll_active_sources with no active sources dispatches nothing."""
        user = MagicMock()
        user.id = "user1"
        mock_db_fn.return_value.collection.return_value.stream.return_value = [user]

        source_repo = AsyncMock()
        source_repo.get_active = AsyncMock(return_value=[])
        mock_repo_fn.return_value = source_repo

        mock_poll_task.delay = MagicMock()

        from app.workers.source_tasks import poll_active_sources

        result = poll_active_sources()

        assert result["sources_dispatched"] == 0
        mock_poll_task.delay.assert_not_called()

    @patch("app.workers.source_tasks.poll_source")
    @patch(_P_SOURCE_REPO)
    @patch(_P_FIRESTORE)
    def test_no_users(self, mock_db_fn, mock_repo_fn, mock_poll_task):
        """poll_active_sources with no users does nothing."""
        mock_db_fn.return_value.collection.return_value.stream.return_value = []

        from app.workers.source_tasks import poll_active_sources

        result = poll_active_sources()

        assert result["users_checked"] == 0
        assert result["sources_dispatched"] == 0


class TestPollSource:
    @patch(_P_SOURCE_SERVICE)
    def test_checks_health(self, mock_service_fn):
        """poll_source should call check_health and return result."""
        service = AsyncMock()
        service.check_health = AsyncMock(return_value={
            "sourceId": "src1",
            "healthScore": 1.0,
            "status": "active",
            "lastChecked": "2026-02-15T00:00:00",
            "error": None,
        })
        mock_service_fn.return_value = service

        from app.workers.source_tasks import poll_source

        result = poll_source("user1", "src1")

        assert result["status"] == "completed"
        assert result["health_score"] == 1.0
        assert result["source_status"] == "active"
        service.check_health.assert_called_once()

    @patch(_P_SOURCE_SERVICE)
    def test_returns_error_status(self, mock_service_fn):
        """poll_source should propagate error status from health check."""
        service = AsyncMock()
        service.check_health = AsyncMock(return_value={
            "sourceId": "src1",
            "healthScore": 0.0,
            "status": "error",
            "lastChecked": "2026-02-15T00:00:00",
            "error": "HTTP 500",
        })
        mock_service_fn.return_value = service

        from app.workers.source_tasks import poll_source

        result = poll_source("user1", "src1")

        assert result["health_score"] == 0.0
        assert result["error"] == "HTTP 500"
