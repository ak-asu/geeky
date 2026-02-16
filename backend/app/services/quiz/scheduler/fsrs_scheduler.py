"""FSRS (Free Spaced Repetition Scheduler) implementation.

Implements the SpacedRepetitionScheduler Protocol using the FSRS algorithm
(AL-01). Uses the py-fsrs library for core scheduling math.

Rating scale: 1=Again, 2=Hard, 3=Good, 4=Easy
"""
from __future__ import annotations

import logging
import math
from datetime import datetime, timedelta, timezone

from app.services.quiz.scheduler.base import CardState, ReviewCard

logger = logging.getLogger(__name__)

# FSRS v4 default parameters
_DEFAULT_W = [
    0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01,
    1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61,
]


class FSRSScheduler:
    """FSRS-based spaced repetition scheduler (AL-01).

    Args:
        desired_retention: Target recall probability (default 0.9).
        weights: FSRS model weights (default: FSRS v4 defaults).
    """

    def __init__(
        self,
        desired_retention: float = 0.9,
        weights: list[float] | None = None,
    ) -> None:
        self._desired_retention = max(0.7, min(0.99, desired_retention))
        self._w = weights or _DEFAULT_W

    def schedule(self, card: ReviewCard, rating: int) -> ReviewCard:
        """Schedule the next review based on user's rating.

        Args:
            card: Current card state.
            rating: User rating (1=Again, 2=Hard, 3=Good, 4=Easy).

        Returns:
            Updated ReviewCard with new scheduling parameters.
        """
        rating = max(1, min(4, rating))
        now = datetime.now(timezone.utc)

        if card.state == CardState.NEW:
            return self._schedule_new(card, rating, now)

        elapsed_days = 0
        if card.last_review_date:
            elapsed_days = max(0, (now - card.last_review_date).days)

        retrievability = self._compute_retrievability(card.stability, elapsed_days)

        if rating == 1:  # Again
            return self._schedule_again(card, now, elapsed_days)
        else:
            return self._schedule_review(card, rating, now, elapsed_days, retrievability)

    def get_retrievability(self, card: ReviewCard) -> float:
        """Get current probability of recall for a card."""
        if card.state == CardState.NEW or card.last_review_date is None:
            return 0.0

        now = datetime.now(timezone.utc)
        elapsed_days = max(0, (now - card.last_review_date).days)
        return self._compute_retrievability(card.stability, elapsed_days)

    def _schedule_new(self, card: ReviewCard, rating: int, now: datetime) -> ReviewCard:
        """Schedule a card being reviewed for the first time."""
        # Initial stability depends on rating
        stability = self._init_stability(rating)
        difficulty = self._init_difficulty(rating)

        if rating == 1:
            # Again on first review -> learning state, review in 1 min equivalent (1 day min)
            interval = 1
            state = CardState.LEARNING
            lapses = 1
        elif rating == 2:
            interval = 1
            state = CardState.LEARNING
            lapses = 0
        else:
            interval = self._next_interval(stability)
            state = CardState.REVIEW
            lapses = 0

        return ReviewCard(
            card_id=card.card_id,
            stability=stability,
            difficulty=difficulty,
            due_date=now + timedelta(days=interval),
            last_review_date=now,
            reps=1,
            lapses=lapses,
            state=state,
        )

    def _schedule_again(self, card: ReviewCard, now: datetime, elapsed_days: int) -> ReviewCard:
        """Handle a lapse (rating=1, forgotten)."""
        new_difficulty = min(10.0, card.difficulty + 2 * self._w[6])
        # Stability after forgetting
        new_stability = self._stability_after_failure(
            card.stability, card.difficulty, elapsed_days
        )
        interval = max(1, self._next_interval(new_stability))

        state = CardState.RELEARNING if card.state == CardState.REVIEW else CardState.LEARNING

        return ReviewCard(
            card_id=card.card_id,
            stability=new_stability,
            difficulty=new_difficulty,
            due_date=now + timedelta(days=interval),
            last_review_date=now,
            reps=card.reps + 1,
            lapses=card.lapses + 1,
            state=state,
        )

    def _schedule_review(
        self,
        card: ReviewCard,
        rating: int,
        now: datetime,
        elapsed_days: int,
        retrievability: float,
    ) -> ReviewCard:
        """Handle successful recall (rating 2-4)."""
        new_difficulty = self._next_difficulty(card.difficulty, rating)
        new_stability = self._stability_after_success(
            card.stability, card.difficulty, retrievability, rating
        )
        interval = self._next_interval(new_stability)

        # Apply hard/easy modifiers
        if rating == 2:
            interval = max(1, int(interval * 0.8))
        elif rating == 4:
            interval = max(1, int(interval * 1.3))

        return ReviewCard(
            card_id=card.card_id,
            stability=new_stability,
            difficulty=new_difficulty,
            due_date=now + timedelta(days=interval),
            last_review_date=now,
            reps=card.reps + 1,
            lapses=card.lapses,
            state=CardState.REVIEW,
        )

    def _init_stability(self, rating: int) -> float:
        """Initial stability for a new card based on first rating."""
        return max(0.1, self._w[rating - 1])

    def _init_difficulty(self, rating: int) -> float:
        """Initial difficulty for a new card based on first rating."""
        return max(1.0, min(10.0, self._w[4] - (rating - 3) * self._w[5]))

    def _next_difficulty(self, d: float, rating: int) -> float:
        """Update difficulty after a review."""
        delta = -(rating - 3) * self._w[6]
        new_d = d + delta
        # Mean reversion toward initial difficulty
        new_d = self._w[7] * self._init_difficulty(3) + (1 - self._w[7]) * new_d
        return max(1.0, min(10.0, new_d))

    def _stability_after_success(
        self, s: float, d: float, r: float, rating: int
    ) -> float:
        """Compute new stability after successful recall."""
        hard_penalty = self._w[15] if rating == 2 else 1.0
        easy_bonus = self._w[16] if rating == 4 else 1.0

        new_s = s * (
            1
            + math.exp(self._w[8])
            * (11 - d)
            * math.pow(s, -self._w[9])
            * (math.exp((1 - r) * self._w[10]) - 1)
            * hard_penalty
            * easy_bonus
        )
        return max(0.1, new_s)

    def _stability_after_failure(self, s: float, d: float, elapsed_days: int) -> float:
        """Compute new stability after a lapse."""
        r = self._compute_retrievability(s, elapsed_days)
        new_s = (
            self._w[11]
            * math.pow(d, -self._w[12])
            * (math.pow(s + 1, self._w[13]) - 1)
            * math.exp((1 - r) * self._w[14])
        )
        return max(0.1, min(new_s, s))

    def _next_interval(self, stability: float) -> int:
        """Compute the next review interval in days from stability."""
        interval = (stability / _FACTOR) * (
            math.pow(self._desired_retention, 1 / _DECAY) - 1
        )
        return max(1, round(interval))

    def _compute_retrievability(self, stability: float, elapsed_days: int) -> float:
        """Compute recall probability given stability and elapsed time."""
        if stability <= 0 or elapsed_days <= 0:
            return 1.0
        return math.pow(1 + elapsed_days / (stability / _FACTOR), _DECAY)


# FSRS constants
_DECAY = -0.5
_FACTOR = 0.9 ** (1 / _DECAY) - 1
