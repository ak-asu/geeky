"""Unit tests for ShortGenerator — CP-07 through CP-11, CP-16, CP-24."""

from __future__ import annotations

import pytest

from app.services.pipeline.chunker import Chunk
from app.services.pipeline.short_generator import GeneratedShort, ShortGenerator
from tests.mocks.mock_llm import MockLLMProvider


@pytest.fixture
def mock_llm():
    return MockLLMProvider()


@pytest.fixture
def generator(mock_llm):
    return ShortGenerator(llm=mock_llm)


def _make_chunk(content: str, section_title: str | None = None, offset: int = 0) -> Chunk:
    return Chunk(
        content=content,
        section_title=section_title,
        offset=offset,
        word_count=len(content.split()),
    )


class TestGeneration:
    @pytest.mark.asyncio
    async def test_generates_one_short_per_chunk(self, generator):
        chunks = [
            _make_chunk("Content about machine learning algorithms.", section_title="ML Basics"),
            _make_chunk("Content about neural network architectures.", section_title="Neural Networks"),
        ]
        results = await generator.generate(chunks, note_id="note-1")
        assert len(results) == len(chunks)

    @pytest.mark.asyncio
    async def test_empty_chunks_returns_empty(self, generator):
        results = await generator.generate([], note_id="note-1")
        assert results == []

    @pytest.mark.asyncio
    async def test_result_is_generated_short(self, generator):
        chunks = [_make_chunk("Some educational content about physics.")]
        results = await generator.generate(chunks, note_id="note-1")
        assert len(results) == 1
        assert isinstance(results[0], GeneratedShort)


class TestPromptStructure:
    @pytest.mark.asyncio
    async def test_llm_called_with_system_prompt(self, mock_llm, generator):
        chunks = [_make_chunk("Test content.", section_title="Test")]
        await generator.generate(chunks, note_id="note-1")

        assert len(mock_llm.calls) == 1
        call = mock_llm.calls[0]
        assert "response_model" in call
        assert call["response_model"] == "GeneratedShort"

    @pytest.mark.asyncio
    async def test_section_title_in_prompt(self, mock_llm, generator):
        chunks = [_make_chunk("Content here.", section_title="My Section Title")]
        await generator.generate(chunks, note_id="note-1")

        call = mock_llm.calls[0]
        assert "My Section Title" in call["prompt"]

    @pytest.mark.asyncio
    async def test_chunk_content_in_prompt(self, mock_llm, generator):
        chunks = [_make_chunk("Unique content about quantum computing.")]
        await generator.generate(chunks, note_id="note-1")

        call = mock_llm.calls[0]
        assert "quantum computing" in call["prompt"]


class TestCoverageConstraint:
    """CP-24: Generation-time dedup via coverage constraints."""

    @pytest.mark.asyncio
    async def test_existing_topics_included_in_constraint(self, mock_llm, generator):
        chunks = [_make_chunk("Content about databases.")]
        await generator.generate(
            chunks,
            note_id="note-1",
            existing_topics=["machine-learning", "neural-networks"],
        )

        call = mock_llm.calls[0]
        assert "machine-learning" in call["prompt"]
        assert "neural-networks" in call["prompt"]
        assert "already been covered" in call["prompt"]

    @pytest.mark.asyncio
    async def test_no_constraint_without_existing_topics(self, mock_llm, generator):
        chunks = [_make_chunk("Content about databases.")]
        await generator.generate(chunks, note_id="note-1")

        call = mock_llm.calls[0]
        assert "already been covered" not in call["prompt"]


class TestGracefulFailure:
    """CP-14: Graceful handling of unprocessable chunks."""

    @pytest.mark.asyncio
    async def test_failed_chunk_produces_fallback_short(self):
        class FailingLLM:
            async def generate_structured(self, prompt, response_model, **kwargs):
                raise RuntimeError("LLM unavailable")

        generator = ShortGenerator(llm=FailingLLM())
        chunks = [_make_chunk("Content that will fail to process.")]
        results = await generator.generate(chunks, note_id="note-1")

        assert len(results) == 1
        # Fallback short should contain the original content
        assert "Content that will fail" in results[0].summary

    @pytest.mark.asyncio
    async def test_partial_failure_continues(self):
        call_count = 0

        class PartialLLM:
            async def generate_structured(self, prompt, response_model, **kwargs):
                nonlocal call_count
                call_count += 1
                if call_count == 2:
                    raise RuntimeError("Intermittent failure")
                return GeneratedShort(
                    title="Generated Title",
                    summary="Generated summary content.",
                    topics=["test"],
                    difficulty=0.5,
                    prompts=["What is this about?"],
                )

        generator = ShortGenerator(llm=PartialLLM())
        chunks = [
            _make_chunk("First chunk."),
            _make_chunk("Second chunk that will fail."),
            _make_chunk("Third chunk."),
        ]
        results = await generator.generate(chunks, note_id="note-1")

        assert len(results) == 3
        assert results[0].title == "Generated Title"
        assert "Second chunk" in results[1].summary  # Fallback
        assert results[2].title == "Generated Title"


class TestConflictDetection:
    """CP-16: Conflict detection between chunks."""

    @pytest.mark.asyncio
    async def test_no_conflicts_when_empty(self, generator):
        shorts = [
            GeneratedShort(title="A", summary="x", conflict_claims=[]),
            GeneratedShort(title="B", summary="y", conflict_claims=[]),
        ]
        conflicts = await generator.detect_conflicts(shorts)
        assert conflicts == []

    @pytest.mark.asyncio
    async def test_detects_overlapping_conflicts(self, generator):
        shorts = [
            GeneratedShort(
                title="A", summary="x",
                conflict_claims=["Earth is flat"],
            ),
            GeneratedShort(
                title="B", summary="y",
                conflict_claims=["Earth is flat according to some"],
            ),
        ]
        conflicts = await generator.detect_conflicts(shorts)
        assert len(conflicts) >= 1
        assert conflicts[0][0] == 0
        assert conflicts[0][1] == 1
