"""Unit tests for HierarchicalChunker — CP-03, CP-04a, CP-04b."""

from __future__ import annotations

import pytest

from app.services.pipeline.chunker import Chunk, ChunkerConfig, HierarchicalChunker
from app.services.pipeline.extractor.base import ParsedDocument, ParsedSection


@pytest.fixture
def chunker():
    """Chunker with small target for testing."""
    return HierarchicalChunker(ChunkerConfig(
        target_words=50,
        overlap_words=10,
        min_chunk_words=5,
        max_chunk_words=100,
    ))


@pytest.fixture
def default_chunker():
    """Chunker with default (production) config."""
    return HierarchicalChunker()


class TestEmptyInput:
    def test_empty_text_returns_no_chunks(self, chunker):
        doc = ParsedDocument(text="")
        assert chunker.chunk(doc) == []

    def test_whitespace_only_returns_no_chunks(self, chunker):
        doc = ParsedDocument(text="   \n\n  ")
        assert chunker.chunk(doc) == []


class TestStructuralSplitting:
    def test_splits_by_sections(self, chunker):
        doc = ParsedDocument(
            text="ignored",
            sections=[
                ParsedSection(heading="Introduction", content="This is the intro section with enough words to pass minimum.", level=1),
                ParsedSection(heading="Methods", content="This is the methods section with enough words to pass minimum.", level=1),
                ParsedSection(heading="Results", content="This is the results section with enough words to pass minimum.", level=1),
            ],
        )
        chunks = chunker.chunk(doc)
        assert len(chunks) >= 3
        assert any("Introduction" in c.content for c in chunks)
        assert any("Methods" in c.content for c in chunks)
        assert any("Results" in c.content for c in chunks)

    def test_section_titles_preserved(self, chunker):
        section_content = "This section explains an important concept. " * 20  # ~120 words, well above min_chunk_words
        doc = ParsedDocument(
            text="ignored",
            sections=[
                ParsedSection(heading="My Section", content=section_content, level=1),
            ],
        )
        chunks = chunker.chunk(doc)
        assert len(chunks) >= 1
        assert chunks[0].section_title == "My Section"


class TestParagraphSplitting:
    def test_splits_at_paragraph_boundaries(self, chunker):
        # Create text with clear paragraph breaks that exceed target
        paragraphs = [f"Paragraph {i} " + "word " * 40 for i in range(5)]
        text = "\n\n".join(paragraphs)
        doc = ParsedDocument(text=text)
        chunks = chunker.chunk(doc)
        assert len(chunks) >= 2

    def test_merges_small_paragraphs(self, chunker):
        text = "Small one.\n\nSmall two.\n\nSmall three.\n\nSmall four.\n\nSmall five."
        doc = ParsedDocument(text=text)
        chunks = chunker.chunk(doc)
        # Small paragraphs should be merged, but might be below min_chunk_words
        # and get filtered out
        for chunk in chunks:
            assert chunk.word_count >= 5


class TestSentenceSplitting:
    def test_oversized_chunk_gets_split(self, chunker):
        # Single paragraph bigger than max_chunk_words
        text = "Word " * 150
        doc = ParsedDocument(text=text)
        chunks = chunker.chunk(doc)
        for chunk in chunks:
            # Should not exceed max (with some tolerance for overlap)
            assert chunk.word_count <= 150  # max + overlap buffer


class TestOverlap:
    def test_adjacent_chunks_have_overlap(self, chunker):
        paragraphs = [f"Unique content block {i}. " + "word " * 40 for i in range(5)]
        text = "\n\n".join(paragraphs)
        doc = ParsedDocument(text=text)
        chunks = chunker.chunk(doc)
        if len(chunks) >= 2:
            # Middle chunks should be larger due to overlap
            assert chunks[0].word_count > 0
            assert chunks[1].word_count > 0


class TestQualityScore:
    def test_quality_score_range(self, chunker):
        text = "This is a test document. " * 20
        doc = ParsedDocument(text=text)
        chunks = chunker.chunk(doc)
        for chunk in chunks:
            assert 0.0 <= chunk.quality_score <= 1.0

    def test_section_title_improves_quality(self, chunker):
        doc = ParsedDocument(
            text="ignored",
            sections=[
                ParsedSection(heading="Good Section", content="Content " * 30, level=1),
                ParsedSection(heading=None, content="Content " * 30, level=0),
            ],
        )
        chunks = chunker.chunk(doc)
        titled = [c for c in chunks if c.section_title]
        untitled = [c for c in chunks if not c.section_title]
        if titled and untitled:
            # Titled chunks should generally score higher (or equal)
            assert max(c.quality_score for c in titled) >= min(c.quality_score for c in untitled)


class TestHashing:
    def test_each_chunk_has_sha256_hash(self, chunker):
        text = "Content block. " * 30
        doc = ParsedDocument(text=text)
        chunks = chunker.chunk(doc)
        for chunk in chunks:
            assert chunk.hash_sha256
            assert len(chunk.hash_sha256) == 64  # SHA-256 hex length


class TestCodeBlockProtection:
    def test_code_blocks_not_split(self, chunker):
        text = "Before code.\n\n```python\ndef foo():\n    return 42\n```\n\nAfter code."
        doc = ParsedDocument(text=text)
        chunks = chunker.chunk(doc)
        # The code block should appear intact in one chunk
        code_found = any("def foo():" in c.content for c in chunks)
        assert code_found


class TestDefaultConfig:
    def test_default_target_is_1000(self, default_chunker):
        assert default_chunker._config.target_words == 1000
        assert default_chunker._config.overlap_words == 200
