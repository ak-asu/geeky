"""Feed ranker — produce a ranked recommendation feed for a user.

Uses the RecommendationScorer to score unseen/unmastered shorts,
then returns them in ranked order.
"""

from __future__ import annotations

import logging
from typing import Any

from app.services.recommendation.base import ScoredShort

logger = logging.getLogger(__name__)


class FeedRanker:
    """Ranked feed producer for the recommendation endpoint.

    Args:
        scorer: Implements RecommendationScorer protocol.
        short_repo: Short repository (for fetching candidate shorts).
        review_state_repo: Review state repository (to exclude mastered shorts).
        interaction_repo: Interaction repository (to identify seen shorts).
    """

    def __init__(
        self,
        *,
        scorer: Any,
        short_repo: Any,
        review_state_repo: Any,
        interaction_repo: Any,
    ) -> None:
        self._scorer = scorer
        self._short_repo = short_repo
        self._review_state_repo = review_state_repo
        self._interaction_repo = interaction_repo

    async def get_ranked_feed(
        self, user_id: str, limit: int = 20
    ) -> list[ScoredShort]:
        """Get a ranked feed of recommended shorts.

        Fetches candidates, filters out mastered ones,
        scores the rest, and returns the top-N.
        """
        # Fetch all user shorts as candidates
        all_shorts = await self._short_repo.query(user_id, limit=500)
        if not all_shorts:
            return []

        # Get mastered short IDs to deprioritize (not exclude)
        review_states = await self._review_state_repo.query(user_id, limit=5000)
        mastered_ids = {
            rs.short_id for rs in review_states if rs.state == "review" and rs.reps >= 3
        }

        # Filter to unmastered candidates first, then mastered as fallback
        candidate_ids = [s.id for s in all_shorts if s.id not in mastered_ids]
        if len(candidate_ids) < limit:
            mastered_candidates = [s.id for s in all_shorts if s.id in mastered_ids]
            candidate_ids.extend(mastered_candidates)

        # Score candidates
        scored = await self._scorer.score(user_id, candidate_ids)

        return scored[:limit]

    async def refresh(self, user_id: str) -> dict:
        """Force recalculation of recommendations.

        Triggers a fresh scoring pass and returns summary.
        """
        feed = await self.get_ranked_feed(user_id, limit=50)
        return {
            "userId": user_id,
            "totalScored": len(feed),
            "topScore": feed[0].score if feed else 0.0,
        }
