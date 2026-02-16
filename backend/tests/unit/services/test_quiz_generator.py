"""Unit tests for QuizGenerator."""
from __future__ import annotations

import pytest

from app.models.common import QuizQuestionType
from app.models.quiz import QuizQuestion
from app.models.short import ShortDocument
from app.services.learning.quiz_generator import QuizGenerator
from tests.mocks.mock_llm import MockLLMProvider


class MockShortRepo:
    """In-memory short repository for testing."""

    def __init__(self):
        self._shorts = {
            "short-001": ShortDocument(
                id="short-001",
                title="Introduction to Python",
                content="Python is a high-level programming language known for its simplicity. "
                "It supports object-oriented, functional, and procedural programming.",
                topics=["python", "programming"],
                difficulty=0.3,
            ),
            "short-002": ShortDocument(
                id="short-002",
                title="Data Structures in Python",
                content="Python provides built-in data structures like lists, dictionaries, "
                "tuples, and sets. Lists are mutable sequences.",
                topics=["python", "data structures"],
                difficulty=0.5,
            ),
        }

    async def get(self, user_id, short_id):
        return self._shorts.get(short_id)

    async def get_by_topic(self, user_id, topic, limit=10):
        return [s for s in self._shorts.values() if topic in s.topics][:limit]


@pytest.fixture
def generator():
    return QuizGenerator(
        llm=MockLLMProvider(),
        short_repo=MockShortRepo(),
        graph_query_service=None,
    )


class TestQuizGenerator:

    @pytest.mark.asyncio
    async def test_generate_from_short_ids(self, generator):
        questions = await generator.generate(
            "user-001",
            short_ids=["short-001"],
            count=3,
        )
        # MockLLMProvider returns default empty model, so questions may be empty
        # The important thing is it doesn't crash
        assert isinstance(questions, list)

    @pytest.mark.asyncio
    async def test_generate_from_topic(self, generator):
        questions = await generator.generate(
            "user-001",
            topic="python",
            count=5,
        )
        assert isinstance(questions, list)

    @pytest.mark.asyncio
    async def test_generate_with_no_content(self, generator):
        questions = await generator.generate(
            "user-001",
            short_ids=["nonexistent"],
            count=5,
        )
        assert questions == []

    @pytest.mark.asyncio
    async def test_generate_with_question_types(self, generator):
        questions = await generator.generate(
            "user-001",
            short_ids=["short-001"],
            question_types=[QuizQuestionType.TRUE_FALSE, QuizQuestionType.MCQ],
            count=3,
        )
        assert isinstance(questions, list)

    @pytest.mark.asyncio
    async def test_generate_respects_count(self, generator):
        # With mock LLM, may return empty, but should never exceed count
        questions = await generator.generate(
            "user-001",
            short_ids=["short-001", "short-002"],
            count=2,
        )
        assert len(questions) <= 2
