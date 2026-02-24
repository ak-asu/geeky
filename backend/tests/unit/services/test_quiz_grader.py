"""Unit tests for QuizGrader."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.common import QuizQuestionType
from app.models.quiz import QuizAnswer, QuizGradeRequest
from app.services.learning.quiz_grader import QuizGrader, _cosine_similarity, _exact_match


def _make_grader(
    quiz_attempt_repo=None,
    bkt_tracker=None,
    short_repo=None,
    embedding_provider=None,
):
    quiz_attempt_repo = quiz_attempt_repo or AsyncMock(create=AsyncMock(return_value="attempt-1"))
    bkt_tracker = bkt_tracker or AsyncMock(update_bkt=AsyncMock(return_value=0.8))
    short_repo = short_repo or AsyncMock(get=AsyncMock(return_value=None))
    return QuizGrader(
        quiz_attempt_repo=quiz_attempt_repo,
        bkt_tracker=bkt_tracker,
        short_repo=short_repo,
        embedding_provider=embedding_provider,
    )


def _make_request(answers: list[tuple[str, str]], short_ids: list[str] = None) -> QuizGradeRequest:
    """Helper to create a QuizGradeRequest from (answer, correct_answer) tuples."""
    return QuizGradeRequest(
        short_ids=short_ids or [],
        answers=[
            QuizAnswer(questionId=f"q{i}", answer=a, correctAnswer=c)
            for i, (a, c) in enumerate(answers)
        ],
    )


class TestGradeAndSave:
    @pytest.mark.asyncio
    async def test_all_correct(self):
        grader = _make_grader()
        body = _make_request([("Paris", "Paris"), ("4", "4")])
        result = await grader.grade_and_save("user-1", body)

        assert result["correctCount"] == 2
        assert result["totalQuestions"] == 2
        assert result["score"] == 1.0
        assert len(result["results"]) == 2
        assert all(r["correct"] for r in result["results"])

    @pytest.mark.asyncio
    async def test_all_incorrect(self):
        grader = _make_grader()
        body = _make_request([("London", "Paris"), ("5", "4")])
        result = await grader.grade_and_save("user-1", body)

        assert result["correctCount"] == 0
        assert result["score"] == 0.0

    @pytest.mark.asyncio
    async def test_case_insensitive_and_stripped(self):
        grader = _make_grader()
        body = _make_request([("  paris  ", "Paris")])
        result = await grader.grade_and_save("user-1", body)

        assert result["correctCount"] == 1

    @pytest.mark.asyncio
    async def test_saves_attempt_via_repo(self):
        repo = AsyncMock()
        repo.create = AsyncMock(return_value="attempt-1")
        grader = _make_grader(quiz_attempt_repo=repo)

        body = _make_request([("a", "a")])
        await grader.grade_and_save("user-1", body)

        repo.create.assert_called_once()
        # First arg = user_id, second = QuizAttemptDocument, third = doc_id
        call_args = repo.create.call_args
        assert call_args.args[0] == "user-1"

    @pytest.mark.asyncio
    async def test_returns_attempt_id(self):
        grader = _make_grader()
        body = _make_request([("a", "a")])
        result = await grader.grade_and_save("user-1", body)

        assert "attemptId" in result
        assert len(result["attemptId"]) > 0

    @pytest.mark.asyncio
    async def test_empty_answers_handled(self):
        grader = _make_grader()
        body = _make_request([])
        result = await grader.grade_and_save("user-1", body)

        assert result["totalQuestions"] == 0
        assert result["correctCount"] == 0
        assert result["score"] == 0.0  # 0/max(0,1) = 0.0

    @pytest.mark.asyncio
    async def test_bkt_called_with_correct_signal_above_50(self):
        """Score >= 50% → correct=True for BKT."""
        bkt = AsyncMock()
        bkt.update_bkt = AsyncMock(return_value=0.8)

        mock_short = MagicMock()
        mock_short.concept_ids = ["c1", "c2"]
        short_repo = AsyncMock()
        short_repo.get = AsyncMock(return_value=mock_short)

        grader = _make_grader(bkt_tracker=bkt, short_repo=short_repo)
        body = _make_request([("a", "a"), ("b", "b")], short_ids=["s1"])
        await grader.grade_and_save("user-1", body)

        # BKT should be called with correct=True (score=1.0 >= 0.5)
        # update_bkt(user_id, concept_id, correct) — all positional
        calls = bkt.update_bkt.call_args_list
        assert len(calls) == 2  # 2 concepts in mock_short
        assert calls[0].args[2] is True

    @pytest.mark.asyncio
    async def test_bkt_failure_does_not_raise(self):
        """BKT errors are logged but do not fail the quiz submission."""
        bkt = AsyncMock()
        bkt.update_bkt = AsyncMock(side_effect=Exception("BKT failed"))

        mock_short = MagicMock()
        mock_short.concept_ids = ["c1"]
        short_repo = AsyncMock()
        short_repo.get = AsyncMock(return_value=mock_short)

        grader = _make_grader(bkt_tracker=bkt, short_repo=short_repo)
        body = _make_request([("a", "a")], short_ids=["s1"])

        # Should NOT raise
        result = await grader.grade_and_save("user-1", body)
        assert result["correctCount"] == 1

    @pytest.mark.asyncio
    async def test_short_not_found_bkt_skipped(self):
        """If short doesn't exist, BKT update is skipped silently."""
        bkt = AsyncMock()
        bkt.update_bkt = AsyncMock()

        short_repo = AsyncMock()
        short_repo.get = AsyncMock(return_value=None)  # not found

        grader = _make_grader(bkt_tracker=bkt, short_repo=short_repo)
        body = _make_request([("a", "a")], short_ids=["nonexistent"])
        await grader.grade_and_save("user-1", body)

        bkt.update_bkt.assert_not_called()


class TestSemanticGrading:
    """Tests for open-ended / short-answer semantic grading path."""

    @pytest.mark.asyncio
    async def test_semantic_correct_above_threshold(self):
        """High-similarity embeddings should be graded correct."""
        mock_embedder = AsyncMock()
        # Two nearly identical unit vectors → similarity ≈ 1.0
        mock_embedder.embed_texts = AsyncMock(return_value=[[1.0, 0.0], [1.0, 0.0]])

        grader = _make_grader(embedding_provider=mock_embedder)
        body = QuizGradeRequest(
            short_ids=[],
            answers=[QuizAnswer(
                questionId="q1",
                answer="Water is H2O",
                correctAnswer="Water consists of hydrogen and oxygen",
                questionType=QuizQuestionType.OPEN_ENDED,
            )],
        )
        result = await grader.grade_and_save("user-1", body)
        assert result["correctCount"] == 1

    @pytest.mark.asyncio
    async def test_semantic_incorrect_below_threshold(self):
        """Low-similarity embeddings should be graded incorrect."""
        mock_embedder = AsyncMock()
        # Orthogonal vectors → similarity = 0.0
        mock_embedder.embed_texts = AsyncMock(return_value=[[1.0, 0.0], [0.0, 1.0]])

        grader = _make_grader(embedding_provider=mock_embedder)
        body = QuizGradeRequest(
            short_ids=[],
            answers=[QuizAnswer(
                questionId="q1",
                answer="completely wrong answer",
                correctAnswer="correct reference answer",
                questionType=QuizQuestionType.SHORT_ANSWER,
            )],
        )
        result = await grader.grade_and_save("user-1", body)
        assert result["correctCount"] == 0

    @pytest.mark.asyncio
    async def test_semantic_fallback_on_embedder_error(self):
        """When embedding fails, falls back to exact match."""
        mock_embedder = AsyncMock()
        mock_embedder.embed_texts = AsyncMock(side_effect=Exception("Embedding API unavailable"))

        grader = _make_grader(embedding_provider=mock_embedder)
        body = QuizGradeRequest(
            short_ids=[],
            answers=[QuizAnswer(
                questionId="q1",
                answer="Paris",
                correctAnswer="Paris",
                questionType=QuizQuestionType.OPEN_ENDED,
            )],
        )
        result = await grader.grade_and_save("user-1", body)
        # Exact match fallback: "Paris" == "Paris" → correct
        assert result["correctCount"] == 1

    @pytest.mark.asyncio
    async def test_open_ended_without_embedder_uses_exact_match(self):
        """When no embedding_provider injected, open-ended uses exact match."""
        grader = _make_grader(embedding_provider=None)
        body = QuizGradeRequest(
            short_ids=[],
            answers=[QuizAnswer(
                questionId="q1",
                answer="paris",
                correctAnswer="Paris",
                questionType=QuizQuestionType.OPEN_ENDED,
            )],
        )
        result = await grader.grade_and_save("user-1", body)
        # Normalised exact match: "paris" == "paris" → correct
        assert result["correctCount"] == 1

    @pytest.mark.asyncio
    async def test_mcq_never_uses_semantic(self):
        """MCQ questions always use exact match, even with embedder wired."""
        mock_embedder = AsyncMock()
        mock_embedder.embed_texts = AsyncMock(return_value=[[1.0, 0.0], [0.0, 1.0]])

        grader = _make_grader(embedding_provider=mock_embedder)
        body = QuizGradeRequest(
            short_ids=[],
            answers=[QuizAnswer(
                questionId="q1",
                answer="A",
                correctAnswer="A",
                questionType=QuizQuestionType.MCQ,
            )],
        )
        result = await grader.grade_and_save("user-1", body)
        # Exact match → correct; embed_texts should NOT have been called
        assert result["correctCount"] == 1
        mock_embedder.embed_texts.assert_not_called()


class TestHelpers:
    def test_cosine_similarity_identical_vectors(self):
        assert _cosine_similarity([1.0, 0.0], [1.0, 0.0]) == pytest.approx(1.0)

    def test_cosine_similarity_orthogonal_vectors(self):
        assert _cosine_similarity([1.0, 0.0], [0.0, 1.0]) == pytest.approx(0.0)

    def test_cosine_similarity_zero_vector(self):
        assert _cosine_similarity([0.0, 0.0], [1.0, 0.0]) == 0.0

    def test_exact_match_normalised(self):
        assert _exact_match("  Paris  ", "paris") is True
        assert _exact_match("London", "Paris") is False
