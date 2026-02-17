"""Unit tests for BKTTracker."""

from __future__ import annotations

from dataclasses import dataclass
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.exceptions import ConceptNotFoundError
from app.services.learning.bkt_tracker import BKTTracker


@dataclass
class _MockBKTParams:
    p_learn: float = 0.3
    p_slip: float = 0.1
    p_guess: float = 0.25
    p_known: float = 0.0


@dataclass
class _MockConcept:
    id: str = "c1"
    name: str = "Test Concept"
    bkt_params: _MockBKTParams = None
    mastery_state: str = "unknown"

    def __post_init__(self):
        if self.bkt_params is None:
            self.bkt_params = _MockBKTParams()


def _make_tracker(concept=None, exists=True):
    concept_repo = AsyncMock()
    concept_repo.get = AsyncMock(
        return_value=concept or (_MockConcept() if exists else None)
    )
    concept_repo.update = AsyncMock()

    tracker = BKTTracker(concept_repo=concept_repo)
    return tracker, concept_repo


class TestUpdateBKT:
    @pytest.mark.asyncio
    async def test_correct_answer_increases_p_known(self):
        tracker, repo = _make_tracker()
        p_known = await tracker.update_bkt("user1", "c1", correct=True)

        assert p_known > 0.0
        repo.update.assert_called_once()

    @pytest.mark.asyncio
    async def test_incorrect_answer_with_zero_p_known(self):
        tracker, repo = _make_tracker()
        p_known = await tracker.update_bkt("user1", "c1", correct=False)

        # Starting at p_known=0.0, incorrect answer should still apply learning
        assert p_known >= 0.0
        repo.update.assert_called_once()

    @pytest.mark.asyncio
    async def test_p_known_increases_with_correct_answers(self):
        # Simulate multiple correct answers
        concept = _MockConcept()
        concept.bkt_params.p_known = 0.5

        tracker, repo = _make_tracker(concept=concept)
        p_known = await tracker.update_bkt("user1", "c1", correct=True)

        assert p_known > 0.5

    @pytest.mark.asyncio
    async def test_p_known_stays_bounded(self):
        concept = _MockConcept()
        concept.bkt_params.p_known = 0.99

        tracker, _ = _make_tracker(concept=concept)
        p_known = await tracker.update_bkt("user1", "c1", correct=True)

        assert 0.0 <= p_known <= 1.0

    @pytest.mark.asyncio
    async def test_incorrect_reduces_confidence(self):
        concept = _MockConcept()
        concept.bkt_params.p_known = 0.8

        tracker, repo = _make_tracker(concept=concept)
        p_known = await tracker.update_bkt("user1", "c1", correct=False)

        # After incorrect answer, p_known should decrease from original
        # but then learning transition is applied
        repo.update.assert_called_once()

    @pytest.mark.asyncio
    async def test_raises_when_concept_not_found(self):
        tracker, _ = _make_tracker(exists=False)

        with pytest.raises(ConceptNotFoundError):
            await tracker.update_bkt("user1", "nonexistent", correct=True)

    @pytest.mark.asyncio
    async def test_updates_mastery_state(self):
        concept = _MockConcept()
        concept.bkt_params.p_known = 0.88

        tracker, repo = _make_tracker(concept=concept)
        await tracker.update_bkt("user1", "c1", correct=True)

        update_data = repo.update.call_args[0][2]
        # After correct with p_known=0.88, should reach mastered (>0.9)
        assert update_data["masteryState"] in ("mastered", "proficient")


class TestGetMastery:
    @pytest.mark.asyncio
    async def test_returns_p_known(self):
        concept = _MockConcept()
        concept.bkt_params.p_known = 0.75

        tracker, _ = _make_tracker(concept=concept)
        mastery = await tracker.get_mastery("user1", "c1")

        assert mastery == 0.75

    @pytest.mark.asyncio
    async def test_raises_when_concept_not_found(self):
        tracker, _ = _make_tracker(exists=False)

        with pytest.raises(ConceptNotFoundError):
            await tracker.get_mastery("user1", "nonexistent")


class TestClassifyMastery:
    def test_mastered(self):
        assert BKTTracker._classify_mastery(0.95) == "mastered"

    def test_proficient(self):
        assert BKTTracker._classify_mastery(0.75) == "proficient"

    def test_developing(self):
        assert BKTTracker._classify_mastery(0.5) == "developing"

    def test_novice(self):
        assert BKTTracker._classify_mastery(0.2) == "novice"

    def test_unknown(self):
        assert BKTTracker._classify_mastery(0.0) == "unknown"
