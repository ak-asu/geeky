"""Unit tests for FSRS Scheduler."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.services.quiz.scheduler.base import CardState, ReviewCard
from app.services.quiz.scheduler.fsrs_scheduler import FSRSScheduler


@pytest.fixture
def scheduler():
    return FSRSScheduler(desired_retention=0.9)


@pytest.fixture
def new_card():
    return ReviewCard(
        card_id="card-001",
        stability=0.0,
        difficulty=0.0,
        due_date=datetime.now(timezone.utc),
        last_review_date=None,
        reps=0,
        lapses=0,
        state=CardState.NEW,
    )


@pytest.fixture
def review_card():
    now = datetime.now(timezone.utc)
    return ReviewCard(
        card_id="card-002",
        stability=5.0,
        difficulty=5.0,
        due_date=now - timedelta(days=1),
        last_review_date=now - timedelta(days=5),
        reps=3,
        lapses=0,
        state=CardState.REVIEW,
    )


class TestFSRSSchedulerNewCard:
    """Tests for scheduling a new card's first review."""

    def test_new_card_again_goes_to_learning(self, scheduler, new_card):
        result = scheduler.schedule(new_card, rating=1)
        assert result.state == CardState.LEARNING
        assert result.lapses == 1
        assert result.reps == 1
        assert result.stability > 0

    def test_new_card_hard_goes_to_learning(self, scheduler, new_card):
        result = scheduler.schedule(new_card, rating=2)
        assert result.state == CardState.LEARNING
        assert result.reps == 1
        assert result.lapses == 0

    def test_new_card_good_goes_to_review(self, scheduler, new_card):
        result = scheduler.schedule(new_card, rating=3)
        assert result.state == CardState.REVIEW
        assert result.reps == 1
        assert result.due_date > datetime.now(timezone.utc)

    def test_new_card_easy_goes_to_review_longer_interval(self, scheduler, new_card):
        good_result = scheduler.schedule(new_card, rating=3)
        easy_result = scheduler.schedule(new_card, rating=4)
        assert easy_result.state == CardState.REVIEW
        # Easy should have higher stability than Good
        assert easy_result.stability >= good_result.stability

    def test_new_card_sets_last_review_date(self, scheduler, new_card):
        result = scheduler.schedule(new_card, rating=3)
        assert result.last_review_date is not None

    def test_new_card_difficulty_varies_by_rating(self, scheduler, new_card):
        again = scheduler.schedule(new_card, rating=1)
        easy = scheduler.schedule(new_card, rating=4)
        # Again should result in higher difficulty than Easy
        assert again.difficulty > easy.difficulty


class TestFSRSSchedulerReviewCard:
    """Tests for scheduling subsequent reviews."""

    def test_again_increases_lapses(self, scheduler, review_card):
        result = scheduler.schedule(review_card, rating=1)
        assert result.lapses == review_card.lapses + 1

    def test_again_transitions_to_relearning(self, scheduler, review_card):
        result = scheduler.schedule(review_card, rating=1)
        assert result.state == CardState.RELEARNING

    def test_good_increases_stability(self, scheduler, review_card):
        result = scheduler.schedule(review_card, rating=3)
        assert result.stability > review_card.stability

    def test_good_stays_in_review(self, scheduler, review_card):
        result = scheduler.schedule(review_card, rating=3)
        assert result.state == CardState.REVIEW

    def test_easy_longer_interval_than_good(self, scheduler, review_card):
        good = scheduler.schedule(review_card, rating=3)
        easy = scheduler.schedule(review_card, rating=4)
        good_interval = (good.due_date - good.last_review_date).days
        easy_interval = (easy.due_date - easy.last_review_date).days
        assert easy_interval >= good_interval

    def test_hard_shorter_interval_than_good(self, scheduler, review_card):
        hard = scheduler.schedule(review_card, rating=2)
        good = scheduler.schedule(review_card, rating=3)
        hard_interval = (hard.due_date - hard.last_review_date).days
        good_interval = (good.due_date - good.last_review_date).days
        assert hard_interval <= good_interval

    def test_reps_always_increment(self, scheduler, review_card):
        for rating in [1, 2, 3, 4]:
            result = scheduler.schedule(review_card, rating=rating)
            assert result.reps == review_card.reps + 1

    def test_rating_clamped(self, scheduler, review_card):
        """Ratings outside 1-4 should be clamped."""
        result_low = scheduler.schedule(review_card, rating=0)
        result_high = scheduler.schedule(review_card, rating=10)
        # Should not crash, ratings are clamped
        assert result_low.reps == review_card.reps + 1
        assert result_high.reps == review_card.reps + 1


class TestFSRSRetrievability:
    """Tests for retrievability computation."""

    def test_new_card_retrievability_is_zero(self, scheduler, new_card):
        assert scheduler.get_retrievability(new_card) == 0.0

    def test_just_reviewed_card_high_retrievability(self, scheduler):
        card = ReviewCard(
            card_id="card-003",
            stability=10.0,
            difficulty=5.0,
            due_date=datetime.now(timezone.utc) + timedelta(days=10),
            last_review_date=datetime.now(timezone.utc),
            reps=5,
            lapses=0,
            state=CardState.REVIEW,
        )
        r = scheduler.get_retrievability(card)
        # Just reviewed: retrievability should be ~1.0
        assert r >= 0.95

    def test_overdue_card_low_retrievability(self, scheduler):
        card = ReviewCard(
            card_id="card-004",
            stability=2.0,
            difficulty=5.0,
            due_date=datetime.now(timezone.utc) - timedelta(days=30),
            last_review_date=datetime.now(timezone.utc) - timedelta(days=30),
            reps=2,
            lapses=0,
            state=CardState.REVIEW,
        )
        r = scheduler.get_retrievability(card)
        assert r < 0.5

    def test_desired_retention_affects_intervals(self):
        strict = FSRSScheduler(desired_retention=0.95)
        relaxed = FSRSScheduler(desired_retention=0.8)

        card = ReviewCard(
            card_id="card-005",
            stability=0.0,
            difficulty=0.0,
            due_date=datetime.now(timezone.utc),
            last_review_date=None,
            reps=0,
            lapses=0,
            state=CardState.NEW,
        )

        strict_result = strict.schedule(card, rating=3)
        relaxed_result = relaxed.schedule(card, rating=3)

        strict_interval = (strict_result.due_date - strict_result.last_review_date).days
        relaxed_interval = (relaxed_result.due_date - relaxed_result.last_review_date).days

        # Higher retention = shorter intervals
        assert strict_interval <= relaxed_interval
