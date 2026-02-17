"""Bayesian Knowledge Tracing (BKT) mastery tracker.

Implements standard BKT update equations to track per-concept mastery
via P(known). Used alongside FSRS (which tracks per-short scheduling)
to provide concept-level mastery estimates.

BKT equations:
  P(correct | known) = 1 - P(slip)
  P(correct | not_known) = P(guess)
  P(known_after | correct) = P(known) * (1 - P(slip)) / P(correct)
  P(known_after | incorrect) = P(known) * P(slip) / P(incorrect)
  P(known_after) = P(known_after | observed) + P(learn) * (1 - P(known_after | observed))
"""

from __future__ import annotations

import logging
from typing import Any

from app.exceptions import ConceptNotFoundError

logger = logging.getLogger(__name__)


class BKTTracker:
    """Bayesian Knowledge Tracing mastery tracker.

    Args:
        concept_repo: Concept document repository.
    """

    def __init__(self, *, concept_repo: Any) -> None:
        self._concept_repo = concept_repo

    async def update_bkt(
        self, user_id: str, concept_id: str, correct: bool
    ) -> float:
        """Update BKT P(known) for a concept after an observation.

        Args:
            user_id: The user ID.
            concept_id: The concept to update.
            correct: Whether the user answered correctly.

        Returns:
            The updated P(known) value.
        """
        concept = await self._concept_repo.get(user_id, concept_id)
        if not concept:
            raise ConceptNotFoundError(concept_id)

        params = concept.bkt_params
        p_known = params.p_known
        p_learn = params.p_learn
        p_slip = params.p_slip
        p_guess = params.p_guess

        # Compute P(correct)
        p_correct = p_known * (1.0 - p_slip) + (1.0 - p_known) * p_guess

        if correct:
            # P(known | correct) via Bayes' rule
            if p_correct > 0:
                p_known_posterior = p_known * (1.0 - p_slip) / p_correct
            else:
                p_known_posterior = p_known
        else:
            # P(known | incorrect) via Bayes' rule
            p_incorrect = 1.0 - p_correct
            if p_incorrect > 0:
                p_known_posterior = p_known * p_slip / p_incorrect
            else:
                p_known_posterior = p_known

        # Apply learning transition
        p_known_new = p_known_posterior + p_learn * (1.0 - p_known_posterior)

        # Clamp to [0, 1]
        p_known_new = max(0.0, min(1.0, p_known_new))

        # Update mastery state based on P(known)
        mastery_state = self._classify_mastery(p_known_new)

        # Persist
        await self._concept_repo.update(user_id, concept_id, {
            "bktParams.pKnown": round(p_known_new, 6),
            "masteryState": mastery_state,
        })

        return p_known_new

    async def get_mastery(self, user_id: str, concept_id: str) -> float:
        """Get the current P(known) for a concept.

        Returns 0.0 if the concept has no BKT state yet.
        """
        concept = await self._concept_repo.get(user_id, concept_id)
        if not concept:
            raise ConceptNotFoundError(concept_id)
        return concept.bkt_params.p_known

    @staticmethod
    def _classify_mastery(p_known: float) -> str:
        """Classify mastery state from P(known) value."""
        if p_known >= 0.9:
            return "mastered"
        if p_known >= 0.7:
            return "proficient"
        if p_known >= 0.4:
            return "developing"
        if p_known > 0.0:
            return "novice"
        return "unknown"
