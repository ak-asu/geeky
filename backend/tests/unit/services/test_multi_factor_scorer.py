"""Unit tests for MultiFactorScorer."""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.recommendation.multi_factor_scorer import MultiFactorScorer


@dataclass
class _MockUser:
    id: str = "user1"
    interests: list = field(default_factory=lambda: ["ml", "python"])
    expertise_level: str = "intermediate"


@dataclass
class _MockShort:
    id: str = "s1"
    title: str = ""
    topics: list = field(default_factory=lambda: ["ml"])
    difficulty: float = 0.5


@dataclass
class _MockReviewState:
    short_id: str = "s1"
    state: str = "new"
    reps: int = 0


@dataclass
class _MockInteraction:
    article_id: str = "s1"


@dataclass
class _MockSettings:
    rec_weight_relevance: float = 0.4
    rec_weight_capability: float = 0.3
    rec_weight_novelty: float = 0.3


def _make_scorer(
    user=None,
    shorts=None,
    review_states=None,
    interactions=None,
):
    user_repo = AsyncMock()
    interaction_repo = AsyncMock()
    review_state_repo = AsyncMock()
    short_repo = AsyncMock()

    user_repo.get = AsyncMock(return_value=user or _MockUser())
    review_state_repo.query = AsyncMock(return_value=review_states or [])
    interaction_repo.query = AsyncMock(return_value=interactions or [])

    # short_repo.get returns the matching short from the list
    shorts_dict = {s.id: s for s in (shorts or [_MockShort()])}
    short_repo.get = AsyncMock(
        side_effect=lambda uid, sid: shorts_dict.get(sid)
    )

    scorer = MultiFactorScorer(
        user_repo=user_repo,
        interaction_repo=interaction_repo,
        review_state_repo=review_state_repo,
        short_repo=short_repo,
        settings=_MockSettings(),
    )
    return scorer


class TestScore:
    @pytest.mark.asyncio
    async def test_scores_shorts(self):
        scorer = _make_scorer()
        scored = await scorer.score("user1", ["s1"])

        assert len(scored) == 1
        assert scored[0].short_id == "s1"
        assert scored[0].score > 0

    @pytest.mark.asyncio
    async def test_empty_short_ids(self):
        scorer = _make_scorer()
        scored = await scorer.score("user1", [])

        assert scored == []

    @pytest.mark.asyncio
    async def test_skips_missing_shorts(self):
        scorer = _make_scorer(shorts=[_MockShort(id="s1")])
        scored = await scorer.score("user1", ["s1", "nonexistent"])

        assert len(scored) == 1
        assert scored[0].short_id == "s1"

    @pytest.mark.asyncio
    async def test_sorted_by_score_descending(self):
        shorts = [
            _MockShort(id="s1", topics=["ml"], difficulty=0.6),
            _MockShort(id="s2", topics=["unrelated"], difficulty=0.9),
        ]
        scorer = _make_scorer(shorts=shorts)
        scored = await scorer.score("user1", ["s1", "s2"])

        assert len(scored) == 2
        assert scored[0].score >= scored[1].score

    @pytest.mark.asyncio
    async def test_novelty_decreases_with_interactions(self):
        shorts = [
            _MockShort(id="s1", topics=["ml"], difficulty=0.5),
            _MockShort(id="s2", topics=["ml"], difficulty=0.5),
        ]
        interactions = [_MockInteraction(article_id="s1")] * 5
        scorer = _make_scorer(shorts=shorts, interactions=interactions)
        scored = await scorer.score("user1", ["s1", "s2"])

        # s2 has no interactions so should be more novel
        s1_score = next(s for s in scored if s.short_id == "s1")
        s2_score = next(s for s in scored if s.short_id == "s2")
        assert s2_score.novelty_score > s1_score.novelty_score

    @pytest.mark.asyncio
    async def test_review_state_affects_capability(self):
        shorts = [
            _MockShort(id="s1", topics=["ml"], difficulty=0.5),
            _MockShort(id="s2", topics=["ml"], difficulty=0.5),
        ]
        review_states = [
            _MockReviewState(short_id="s1", state="review"),
            _MockReviewState(short_id="s2", state="relearning"),
        ]
        scorer = _make_scorer(shorts=shorts, review_states=review_states)
        scored = await scorer.score("user1", ["s1", "s2"])

        s1 = next(s for s in scored if s.short_id == "s1")
        s2 = next(s for s in scored if s.short_id == "s2")
        # Relearning should have higher capability score than review (already mastered)
        assert s2.capability_score > s1.capability_score


class TestComputeRelevance:
    def test_full_overlap(self):
        score = MultiFactorScorer._compute_relevance({"ml", "python"}, ["ml", "python"])
        assert score == 1.0

    def test_partial_overlap(self):
        score = MultiFactorScorer._compute_relevance({"ml", "python"}, ["ml", "rust"])
        assert score == 0.5

    def test_no_overlap(self):
        score = MultiFactorScorer._compute_relevance({"ml"}, ["cooking"])
        assert score == 0.0

    def test_empty_topics(self):
        score = MultiFactorScorer._compute_relevance({"ml"}, [])
        assert score == 0.1

    def test_no_user_interests(self):
        score = MultiFactorScorer._compute_relevance(set(), ["ml"])
        assert score == 0.5


class TestComputeNovelty:
    def test_zero_interactions(self):
        assert MultiFactorScorer._compute_novelty(0) == 1.0

    def test_many_interactions(self):
        score = MultiFactorScorer._compute_novelty(10)
        assert 0.0 < score < 0.5

    def test_decreasing_with_count(self):
        assert MultiFactorScorer._compute_novelty(1) > MultiFactorScorer._compute_novelty(5)
