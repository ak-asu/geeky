"""Multi-factor recommendation scorer (AL-02).

Scores shorts using four factors:
- Relevance (40%): topic overlap between user interests and short topics
- Capability (30%): match short difficulty to user mastery level
- Novelty (30%): inverse interaction count (fewer views = more novel)
- Geographic boost (+12% additive): local content relevance when enabled
"""

from __future__ import annotations

import logging
import math
from typing import Any

from app.config import Settings
from app.services.recommendation.base import ScoredShort
from app.services.recommendation.location_scorer import LocationScorer

logger = logging.getLogger(__name__)


class MultiFactorScorer:
    """Multi-factor recommendation scorer implementing RecommendationScorer protocol.

    Args:
        user_repo: User repository for interests/expertise.
        interaction_repo: Interaction repository for novelty computation.
        review_state_repo: Review state repository for mastery levels.
        short_repo: Short repository for short metadata.
        settings: Application settings with weight configuration.
        location_scorer: Geographic relevance scorer (optional, injected).
    """

    def __init__(
        self,
        *,
        user_repo: Any,
        interaction_repo: Any,
        review_state_repo: Any,
        short_repo: Any,
        settings: Settings,
        location_scorer: LocationScorer | None = None,
    ) -> None:
        self._user_repo = user_repo
        self._interaction_repo = interaction_repo
        self._review_state_repo = review_state_repo
        self._short_repo = short_repo
        self._w_relevance = settings.rec_weight_relevance
        self._w_capability = settings.rec_weight_capability
        self._w_novelty = settings.rec_weight_novelty
        self._location_boost = settings.rec_location_boost
        self._location_scorer = location_scorer or LocationScorer()

    async def score(
        self, user_id: str, short_ids: list[str]
    ) -> list[ScoredShort]:
        """Score a list of shorts for the user.

        Returns scored shorts sorted by descending score.
        """
        if not short_ids:
            return []

        # Fetch user profile
        user = await self._user_repo.get(user_id)
        user_interests = set(user.interests) if user else set()
        user_expertise = user.expertise_level if user else "beginner"
        home_region: str | None = getattr(user, "home_region", None) if user else None
        location_enabled: bool = getattr(user, "location_enabled", False) if user else False

        # Fetch review states for mastery info
        review_states = await self._review_state_repo.query(user_id, limit=5000)
        mastery_by_short: dict[str, str] = {
            rs.short_id: rs.state for rs in review_states
        }

        # Fetch interaction counts for novelty
        interactions = await self._interaction_repo.query(user_id, limit=5000)
        interaction_counts: dict[str, int] = {}
        for interaction in interactions:
            interaction_counts[interaction.article_id] = (
                interaction_counts.get(interaction.article_id, 0) + 1
            )

        # Score each short
        scored: list[ScoredShort] = []
        for short_id in short_ids:
            short = await self._short_repo.get(user_id, short_id)
            if not short:
                continue

            relevance = self._compute_relevance(user_interests, short.topics)
            capability = self._compute_capability(
                user_expertise, short.difficulty, mastery_by_short.get(short_id)
            )
            novelty = self._compute_novelty(interaction_counts.get(short_id, 0))

            base_score = (
                self._w_relevance * relevance
                + self._w_capability * capability
                + self._w_novelty * novelty
            )

            # Geographic boost — additive, only when user has enabled location
            # and has a home region set. Gracefully no-ops when disabled.
            geo_score = 0.0
            if location_enabled and home_region:
                content_locations = getattr(short, "location_entities", []) or []
                geo_score = self._location_scorer.compute_score(
                    content_locations, home_region
                )

            total = base_score + self._location_boost * geo_score

            scored.append(ScoredShort(
                short_id=short_id,
                score=round(total, 4),
                relevance_score=round(relevance, 4),
                capability_score=round(capability, 4),
                novelty_score=round(novelty, 4),
            ))

        scored.sort(key=lambda s: s.score, reverse=True)
        return scored

    @staticmethod
    def _compute_relevance(
        user_interests: set[str], short_topics: list[str]
    ) -> float:
        """Compute relevance as Jaccard-like topic overlap.

        Returns 1.0 if all short topics match user interests,
        0.0 if none match, with a small baseline for discovery.
        """
        if not short_topics:
            return 0.1  # Small baseline for topicless shorts

        short_topic_set = set(t.lower() for t in short_topics)
        interest_set = set(i.lower() for i in user_interests)

        if not interest_set:
            return 0.5  # Neutral if user has no interests set

        overlap = len(short_topic_set & interest_set)
        return overlap / len(short_topic_set)

    @staticmethod
    def _compute_capability(
        user_expertise: str,
        short_difficulty: float,
        mastery_state: str | None,
    ) -> float:
        """Compute capability match between user level and short difficulty.

        Returns high score when difficulty is in the user's zone of
        proximal development (slightly above current mastery).
        """
        expertise_levels = {
            "beginner": 0.2,
            "intermediate": 0.5,
            "advanced": 0.8,
            "expert": 0.95,
        }
        user_level = expertise_levels.get(user_expertise, 0.3)

        # Boost mastery if they've already reviewed it
        if mastery_state == "review":
            return 0.3  # Already mastered — lower priority
        if mastery_state == "relearning":
            return 0.9  # Needs reinforcement — high priority

        # Ideal difficulty is slightly above user level
        ideal_difficulty = min(user_level + 0.15, 1.0)
        distance = abs(short_difficulty - ideal_difficulty)
        return max(0.0, 1.0 - distance * 2.0)

    @staticmethod
    def _compute_novelty(interaction_count: int) -> float:
        """Compute novelty as inverse of interaction frequency.

        Uses logarithmic decay: more interactions = less novel.
        """
        if interaction_count == 0:
            return 1.0
        return 1.0 / (1.0 + math.log1p(interaction_count))
