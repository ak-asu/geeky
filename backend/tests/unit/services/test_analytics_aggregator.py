"""Unit tests for AnalyticsAggregator."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.analytics.aggregator import AnalyticsAggregator


@dataclass
class _MockReviewState:
    id: str
    short_id: str
    state: str
    reps: int = 0


@dataclass
class _MockShort:
    id: str
    title: str = ""
    content: str = ""
    topics: list = field(default_factory=list)


@dataclass
class _MockInteraction:
    id: str
    time_spent: float = 0.0
    timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class _MockUser:
    id: str
    streak: MagicMock = field(default_factory=lambda: MagicMock(
        current=5, longest=10, last_active_date="2026-02-15",
        weekly_activity=[True, True, True, True, True, False, False]
    ))


def _make_repos(
    notes=0, shorts=None, concepts=0,
    review_states=None, interactions=None,
    quiz_attempts=0, user=None,
):
    """Create mock repositories with specified data."""
    note_repo = AsyncMock()
    note_repo.count = AsyncMock(return_value=notes)

    short_repo = AsyncMock()
    shorts_list = shorts or []
    short_repo.count = AsyncMock(return_value=len(shorts_list))
    short_repo.query = AsyncMock(return_value=shorts_list)

    concept_repo = AsyncMock()
    concept_repo.count = AsyncMock(return_value=concepts)

    review_state_repo = AsyncMock()
    rs_list = review_states or []
    review_state_repo.count = AsyncMock(return_value=len(rs_list))
    review_state_repo.query = AsyncMock(return_value=rs_list)

    interaction_repo = AsyncMock()
    interactions_list = interactions or []
    interaction_repo.query = AsyncMock(return_value=interactions_list)

    quiz_attempt_repo = AsyncMock()
    quiz_attempt_repo.count = AsyncMock(return_value=quiz_attempts)

    user_repo = AsyncMock()
    user_repo.get = AsyncMock(return_value=user or _MockUser("user1"))

    return {
        "note_repo": note_repo,
        "short_repo": short_repo,
        "concept_repo": concept_repo,
        "review_state_repo": review_state_repo,
        "interaction_repo": interaction_repo,
        "quiz_attempt_repo": quiz_attempt_repo,
        "user_repo": user_repo,
    }


class TestGetDashboard:
    @pytest.mark.asyncio
    async def test_returns_dashboard_with_counts(self):
        repos = _make_repos(notes=5, concepts=10, shorts=[
            _MockShort("s1", topics=["ml"]),
            _MockShort("s2", topics=["python"]),
        ])
        aggregator = AnalyticsAggregator(**repos)
        dashboard = await aggregator.get_dashboard("user1")

        assert dashboard.total_notes == 5
        assert dashboard.total_shorts == 2
        assert dashboard.total_concepts == 10

    @pytest.mark.asyncio
    async def test_returns_streak_info(self):
        repos = _make_repos()
        aggregator = AnalyticsAggregator(**repos)
        dashboard = await aggregator.get_dashboard("user1")

        assert dashboard.streak.current == 5
        assert dashboard.streak.longest == 10

    @pytest.mark.asyncio
    async def test_returns_achievements(self):
        repos = _make_repos(notes=1, shorts=[_MockShort("s1")])
        aggregator = AnalyticsAggregator(**repos)
        dashboard = await aggregator.get_dashboard("user1")

        assert len(dashboard.achievements) > 0
        first_note = next(a for a in dashboard.achievements if a.id == "first_note")
        assert first_note.unlocked is True

    @pytest.mark.asyncio
    async def test_empty_user_returns_defaults(self):
        repos = _make_repos()
        aggregator = AnalyticsAggregator(**repos)
        dashboard = await aggregator.get_dashboard("user1")

        assert dashboard.total_notes == 0
        assert dashboard.total_shorts == 0


class TestGetStreak:
    @pytest.mark.asyncio
    async def test_returns_streak_from_user(self):
        repos = _make_repos()
        aggregator = AnalyticsAggregator(**repos)
        streak = await aggregator.get_streak("user1")

        assert streak.current == 5
        assert streak.longest == 10

    @pytest.mark.asyncio
    async def test_missing_user_returns_empty(self):
        repos = _make_repos()
        repos["user_repo"].get = AsyncMock(return_value=None)
        aggregator = AnalyticsAggregator(**repos)
        streak = await aggregator.get_streak("user1")

        assert streak.current == 0


class TestGetMasteryDistribution:
    @pytest.mark.asyncio
    async def test_counts_by_state(self):
        review_states = [
            _MockReviewState("r1", "s1", "new"),
            _MockReviewState("r2", "s2", "learning"),
            _MockReviewState("r3", "s3", "review"),
            _MockReviewState("r4", "s4", "review"),
            _MockReviewState("r5", "s5", "relearning"),
        ]
        repos = _make_repos(review_states=review_states)
        aggregator = AnalyticsAggregator(**repos)
        mastery = await aggregator.get_mastery_distribution("user1")

        assert mastery.new == 1
        assert mastery.learning == 1
        assert mastery.review == 2
        assert mastery.relearning == 1
        assert mastery.total == 5

    @pytest.mark.asyncio
    async def test_empty_review_states(self):
        repos = _make_repos()
        aggregator = AnalyticsAggregator(**repos)
        mastery = await aggregator.get_mastery_distribution("user1")

        assert mastery.total == 0
        assert mastery.new == 0


class TestTopicProgress:
    @pytest.mark.asyncio
    async def test_groups_by_topic(self):
        shorts = [
            _MockShort("s1", topics=["ml"]),
            _MockShort("s2", topics=["ml"]),
            _MockShort("s3", topics=["python"]),
        ]
        review_states = [
            _MockReviewState("r1", "s1", "review"),
            _MockReviewState("r2", "s2", "learning"),
        ]
        repos = _make_repos(shorts=shorts, review_states=review_states)
        aggregator = AnalyticsAggregator(**repos)
        dashboard = await aggregator.get_dashboard("user1")

        ml_topic = next(t for t in dashboard.topics_progress if t.topic == "ml")
        assert ml_topic.total_shorts == 2
        assert ml_topic.shorts_completed == 1  # only s1 is "review"

        python_topic = next(t for t in dashboard.topics_progress if t.topic == "python")
        assert python_topic.total_shorts == 1
        assert python_topic.shorts_completed == 0
