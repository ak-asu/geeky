"""Unit tests for SyncService."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.common import InteractionType
from app.models.interaction import InteractionCreate
from app.services.sync.sync_service import SyncService


@dataclass
class _MockUser:
    id: str = "user1"
    streak: MagicMock = field(
        default_factory=lambda: MagicMock(
            current=3,
            longest=7,
            last_active_date="2026-02-14",
            weekly_activity=[True, True, True, False, False, False, False],
        )
    )


def _make_service(user=None):
    interaction_repo = AsyncMock()
    user_repo = AsyncMock()

    interaction_repo.create_batch = AsyncMock(return_value=3)
    user_repo.get = AsyncMock(return_value=user or _MockUser())
    user_repo.update = AsyncMock()

    service = SyncService(
        interaction_repo=interaction_repo,
        user_repo=user_repo,
    )
    return service, interaction_repo, user_repo


def _make_interaction(article_id="s1"):
    return InteractionCreate(
        article_id=article_id,
        type=InteractionType.VIEW,
        timestamp=datetime.now(timezone.utc),
        time_spent=30.0,
    )


class TestBatchSync:
    @pytest.mark.asyncio
    async def test_syncs_interactions(self):
        service, interaction_repo, _ = _make_service()
        interactions = [_make_interaction("s1"), _make_interaction("s2"), _make_interaction("s3")]
        result = await service.batch_sync("user1", interactions)

        assert result["synced"] == 3
        assert result["failed"] == 0
        interaction_repo.create_batch.assert_called_once()

    @pytest.mark.asyncio
    async def test_empty_batch(self):
        service, interaction_repo, _ = _make_service()
        result = await service.batch_sync("user1", [])

        assert result["synced"] == 0
        assert result["failed"] == 0
        interaction_repo.create_batch.assert_not_called()

    @pytest.mark.asyncio
    async def test_partial_sync(self):
        service, interaction_repo, _ = _make_service()
        interaction_repo.create_batch = AsyncMock(return_value=2)
        interactions = [_make_interaction("s1"), _make_interaction("s2"), _make_interaction("s3")]
        result = await service.batch_sync("user1", interactions)

        assert result["synced"] == 2
        assert result["failed"] == 1


class TestUpdateStreak:
    @pytest.mark.asyncio
    async def test_increments_streak_on_consecutive_day(self):
        # User was last active yesterday (2026-02-14),
        # today is 2026-02-15
        service, _, user_repo = _make_service()

        with patch("app.services.sync.sync_service.datetime") as mock_dt:
            mock_dt.now.return_value = datetime(2026, 2, 15, 12, 0, tzinfo=timezone.utc)
            mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)

            interactions = [_make_interaction()]
            await service.batch_sync("user1", interactions)

        user_repo.update.assert_called_once()
        update_data = user_repo.update.call_args[0][1]
        assert update_data["streak.current"] == 4  # 3 + 1

    @pytest.mark.asyncio
    async def test_resets_streak_on_gap(self):
        # User was last active 2 days ago
        user = _MockUser()
        user.streak.last_active_date = "2026-02-12"
        service, _, user_repo = _make_service(user=user)

        with patch("app.services.sync.sync_service.datetime") as mock_dt:
            mock_dt.now.return_value = datetime(2026, 2, 15, 12, 0, tzinfo=timezone.utc)
            mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)

            await service.batch_sync("user1", [_make_interaction()])

        update_data = user_repo.update.call_args[0][1]
        assert update_data["streak.current"] == 1

    @pytest.mark.asyncio
    async def test_no_update_if_already_active_today(self):
        user = _MockUser()
        user.streak.last_active_date = "2026-02-15"
        service, _, user_repo = _make_service(user=user)

        with patch("app.services.sync.sync_service.datetime") as mock_dt:
            mock_dt.now.return_value = datetime(2026, 2, 15, 12, 0, tzinfo=timezone.utc)
            mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)

            await service.batch_sync("user1", [_make_interaction()])

        user_repo.update.assert_not_called()

    @pytest.mark.asyncio
    async def test_no_update_if_user_not_found(self):
        service, _, user_repo = _make_service()
        user_repo.get = AsyncMock(return_value=None)

        await service.batch_sync("user1", [_make_interaction()])

        user_repo.update.assert_not_called()
