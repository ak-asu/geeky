"""Unit tests for quiz generation Celery tasks."""

from __future__ import annotations

from dataclasses import dataclass
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# Patch targets — lazy imports from app.dependencies
_P_QUIZ_GEN = "app.dependencies.get_quiz_generator"
_P_QUIZ_REPO = "app.dependencies.get_quiz_repository"


@dataclass
class _MockQuizQuestion:
    id: str = "q1"
    text: str = "What is ML?"
    type: str = "mcq"


class TestGenerateQuizForShort:
    @patch(_P_QUIZ_REPO)
    @patch(_P_QUIZ_GEN)
    def test_generates_and_stores_questions(self, mock_gen_fn, mock_repo_fn):
        """Should generate questions via QuizGenerator and store them."""
        generator = AsyncMock()
        questions = [_MockQuizQuestion(id="q1"), _MockQuizQuestion(id="q2")]
        generator.generate = AsyncMock(return_value=questions)
        mock_gen_fn.return_value = generator

        quiz_repo = AsyncMock()
        quiz_repo.create = AsyncMock(return_value="stored-id")
        mock_repo_fn.return_value = quiz_repo

        from app.workers.quiz_tasks import generate_quiz_for_short

        result = generate_quiz_for_short("user1", "short1")

        assert result["status"] == "completed"
        assert result["questions_generated"] == 2
        assert result["questions_stored"] == 2
        generator.generate.assert_called_once_with("user1", short_ids=["short1"], count=5)
        assert quiz_repo.create.call_count == 2

    @patch(_P_QUIZ_REPO)
    @patch(_P_QUIZ_GEN)
    def test_no_questions_generated(self, mock_gen_fn, mock_repo_fn):
        """Should handle case when generator returns no questions."""
        generator = AsyncMock()
        generator.generate = AsyncMock(return_value=[])
        mock_gen_fn.return_value = generator

        quiz_repo = AsyncMock()
        mock_repo_fn.return_value = quiz_repo

        from app.workers.quiz_tasks import generate_quiz_for_short

        result = generate_quiz_for_short("user1", "short1")

        assert result["questions_generated"] == 0
        assert result["questions_stored"] == 0
        quiz_repo.create.assert_not_called()

    @patch(_P_QUIZ_REPO)
    @patch(_P_QUIZ_GEN)
    def test_passes_correct_short_id(self, mock_gen_fn, mock_repo_fn):
        """Should pass the short_id correctly to the generator."""
        generator = AsyncMock()
        generator.generate = AsyncMock(return_value=[])
        mock_gen_fn.return_value = generator

        quiz_repo = AsyncMock()
        mock_repo_fn.return_value = quiz_repo

        from app.workers.quiz_tasks import generate_quiz_for_short

        generate_quiz_for_short("user42", "short-xyz")

        generator.generate.assert_called_once_with("user42", short_ids=["short-xyz"], count=5)
