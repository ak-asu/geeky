"""Unit tests for SubscriptionService quota enforcement."""
from __future__ import annotations

from datetime import date
from unittest.mock import AsyncMock

import pytest

from app.exceptions import PremiumRequiredError
from app.models.common import SubscriptionTier
from app.models.user import UserDocument
from app.services.subscription.subscription_service import SubscriptionService


def _make_service(user_repo=None, note_repo=None, source_repo=None) -> SubscriptionService:
    return SubscriptionService(
        user_repo=user_repo or AsyncMock(),
        note_repo=note_repo or AsyncMock(),
        source_repo=source_repo or AsyncMock(),
    )


def _free_user(rag_today: int = 0, rag_date: str = "") -> UserDocument:
    return UserDocument(
        id="u1",
        subscriptionTier=SubscriptionTier.FREE,
        ragQueriesToday=rag_today,
        ragQueriesDate=rag_date,
    )


def _premium_user() -> UserDocument:
    return UserDocument(id="u1", subscriptionTier=SubscriptionTier.PREMIUM)


class TestCheckNotesQuota:
    @pytest.mark.asyncio
    async def test_free_user_under_limit_allowed(self):
        user_repo = AsyncMock(get=AsyncMock(return_value=_free_user()))
        note_repo = AsyncMock(count=AsyncMock(return_value=10))  # 10 < 50
        svc = _make_service(user_repo=user_repo, note_repo=note_repo)

        await svc.check_notes_quota("u1")  # must not raise

    @pytest.mark.asyncio
    async def test_free_user_at_limit_raises(self):
        user_repo = AsyncMock(get=AsyncMock(return_value=_free_user()))
        note_repo = AsyncMock(count=AsyncMock(return_value=50))  # 50 >= 50
        svc = _make_service(user_repo=user_repo, note_repo=note_repo)

        with pytest.raises(PremiumRequiredError):
            await svc.check_notes_quota("u1")

    @pytest.mark.asyncio
    async def test_free_user_over_limit_raises(self):
        user_repo = AsyncMock(get=AsyncMock(return_value=_free_user()))
        note_repo = AsyncMock(count=AsyncMock(return_value=75))
        svc = _make_service(user_repo=user_repo, note_repo=note_repo)

        with pytest.raises(PremiumRequiredError):
            await svc.check_notes_quota("u1")

    @pytest.mark.asyncio
    async def test_premium_user_never_blocked(self):
        user_repo = AsyncMock(get=AsyncMock(return_value=_premium_user()))
        note_repo = AsyncMock(count=AsyncMock(return_value=9999))
        svc = _make_service(user_repo=user_repo, note_repo=note_repo)

        await svc.check_notes_quota("u1")
        # count() must NOT be called for premium (early return)
        note_repo.count.assert_not_called()

    @pytest.mark.asyncio
    async def test_missing_user_defaults_to_free_limits(self):
        """None user is treated as free tier."""
        user_repo = AsyncMock(get=AsyncMock(return_value=None))
        note_repo = AsyncMock(count=AsyncMock(return_value=50))
        svc = _make_service(user_repo=user_repo, note_repo=note_repo)

        with pytest.raises(PremiumRequiredError):
            await svc.check_notes_quota("u1")


class TestCheckSourcesQuota:
    @pytest.mark.asyncio
    async def test_free_user_under_limit_allowed(self):
        user_repo = AsyncMock(get=AsyncMock(return_value=_free_user()))
        source_repo = AsyncMock(count=AsyncMock(return_value=2))  # 2 < 3
        svc = _make_service(user_repo=user_repo, source_repo=source_repo)

        await svc.check_sources_quota("u1")

    @pytest.mark.asyncio
    async def test_free_user_at_limit_raises(self):
        user_repo = AsyncMock(get=AsyncMock(return_value=_free_user()))
        source_repo = AsyncMock(count=AsyncMock(return_value=3))  # 3 >= 3
        svc = _make_service(user_repo=user_repo, source_repo=source_repo)

        with pytest.raises(PremiumRequiredError):
            await svc.check_sources_quota("u1")

    @pytest.mark.asyncio
    async def test_premium_user_bypasses_limit(self):
        user_repo = AsyncMock(get=AsyncMock(return_value=_premium_user()))
        source_repo = AsyncMock(count=AsyncMock(return_value=999))
        svc = _make_service(user_repo=user_repo, source_repo=source_repo)

        await svc.check_sources_quota("u1")
        source_repo.count.assert_not_called()


class TestCheckRagQuota:
    @pytest.mark.asyncio
    async def test_premium_user_always_allowed(self):
        user_repo = AsyncMock(get=AsyncMock(return_value=_premium_user()))
        svc = _make_service(user_repo=user_repo)

        await svc.check_rag_quota("u1")
        # No update should happen — unlimited tier exits early
        user_repo.update.assert_not_called()

    @pytest.mark.asyncio
    async def test_new_day_resets_counter_and_allows(self):
        yesterday = "2026-02-16"
        user = _free_user(rag_today=10, rag_date=yesterday)
        user_repo = AsyncMock(get=AsyncMock(return_value=user), update=AsyncMock())
        svc = _make_service(user_repo=user_repo)

        await svc.check_rag_quota("u1")  # must not raise

        user_repo.update.assert_called_once()
        update_data = user_repo.update.call_args.args[1]
        assert update_data["ragQueriesToday"] == 1

    @pytest.mark.asyncio
    async def test_empty_date_treated_as_new_day(self):
        """Brand-new user with no prior RAG usage gets the new-day reset path."""
        user = _free_user(rag_today=0, rag_date="")
        user_repo = AsyncMock(get=AsyncMock(return_value=user), update=AsyncMock())
        svc = _make_service(user_repo=user_repo)

        await svc.check_rag_quota("u1")
        user_repo.update.assert_called_once()

    @pytest.mark.asyncio
    async def test_under_limit_increments_counter(self):
        today = date.today().isoformat()
        user = _free_user(rag_today=5, rag_date=today)
        user_repo = AsyncMock(get=AsyncMock(return_value=user), update=AsyncMock())
        svc = _make_service(user_repo=user_repo)

        await svc.check_rag_quota("u1")

        user_repo.update.assert_called_once_with("u1", {"ragQueriesToday": 6})

    @pytest.mark.asyncio
    async def test_at_limit_raises_without_update(self):
        today = date.today().isoformat()
        user = _free_user(rag_today=10, rag_date=today)  # 10 >= 10 daily limit
        user_repo = AsyncMock(get=AsyncMock(return_value=user))
        svc = _make_service(user_repo=user_repo)

        with pytest.raises(PremiumRequiredError):
            await svc.check_rag_quota("u1")

        # Counter must NOT be incremented when limit exceeded
        user_repo.update.assert_not_called()

    @pytest.mark.asyncio
    async def test_one_below_limit_allowed(self):
        today = date.today().isoformat()
        user = _free_user(rag_today=9, rag_date=today)  # 9 < 10
        user_repo = AsyncMock(get=AsyncMock(return_value=user), update=AsyncMock())
        svc = _make_service(user_repo=user_repo)

        await svc.check_rag_quota("u1")
        user_repo.update.assert_called_once_with("u1", {"ragQueriesToday": 10})
