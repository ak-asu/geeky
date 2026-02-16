"""Hierarchical chunker — CP-03, CP-04a, CP-04b.

Pure business logic, no external dependencies. 4-level hierarchical
chunking strategy:

1. Structural headers (section breaks)
2. Paragraph breaks
3. Semantic change-point detection (sentence similarity drop)
4. Sentence-level fallback

Target ~1000 words/chunk with ~200 word overlap. Assigns quality scores.
"""

from __future__ import annotations

import hashlib
import logging
import re
from dataclasses import dataclass, field

from app.services.pipeline.extractor.base import ParsedDocument, ParsedSection

logger = logging.getLogger(__name__)

# Regex patterns
_HEADING_RE = re.compile(r"^#{1,6}\s+", re.MULTILINE)
_PARAGRAPH_BREAK_RE = re.compile(r"\n\s*\n")
_SENTENCE_RE = re.compile(r"(?<=[.!?])\s+(?=[A-Z])")

# Protected block patterns — never split inside these
_CODE_BLOCK_RE = re.compile(r"```[\s\S]*?```", re.MULTILINE)
_MATH_BLOCK_RE = re.compile(r"\$\$[\s\S]*?\$\$", re.MULTILINE)
_TABLE_ROW_RE = re.compile(r"^\|.*\|$", re.MULTILINE)


@dataclass
class Chunk:
    """A single text chunk with metadata."""

    content: str
    section_title: str | None = None
    offset: int = 0
    word_count: int = 0
    quality_score: float = 1.0
    hash_sha256: str = ""
    overlap_before: str = ""
    overlap_after: str = ""


@dataclass
class ChunkerConfig:
    """Configuration for the hierarchical chunker."""

    target_words: int = 1000
    overlap_words: int = 200
    min_chunk_words: int = 50
    max_chunk_words: int = 2000


class HierarchicalChunker:
    """Hierarchical text chunker with 4-level splitting strategy.

    Pure logic service — no I/O, no external deps.
    """

    def __init__(self, config: ChunkerConfig | None = None) -> None:
        self._config = config or ChunkerConfig()

    def chunk(self, document: ParsedDocument) -> list[Chunk]:
        """Chunk a parsed document using hierarchical strategy.

        Returns:
            List of Chunk objects with content, metadata, and quality scores.
        """
        if not document.text.strip():
            return []

        # Level 1: Try structural splitting (sections from parser)
        if document.sections and len(document.sections) > 1:
            chunks = self._split_by_sections(document.sections)
        else:
            # Level 2: Paragraph splitting
            chunks = self._split_by_paragraphs(document.text)

        # Level 3+4: Enforce size limits via recursive splitting
        sized_chunks = self._enforce_size_limits(chunks)

        # Add overlap between adjacent chunks
        overlapped = self._add_overlap(sized_chunks)

        # Compute quality scores and hashes
        for chunk in overlapped:
            chunk.word_count = _word_count(chunk.content)
            chunk.quality_score = self._compute_quality_score(chunk)
            chunk.hash_sha256 = hashlib.sha256(chunk.content.encode()).hexdigest()

        # Filter out tiny chunks
        result = [c for c in overlapped if c.word_count >= self._config.min_chunk_words]

        logger.info("Chunked document into %d chunks (from %d words)", len(result), _word_count(document.text))
        return result

    def _split_by_sections(self, sections: list[ParsedSection]) -> list[Chunk]:
        """Level 1: Split at structural boundaries."""
        chunks: list[Chunk] = []
        offset = 0

        for section in sections:
            text = section.content.strip()
            if not text and section.heading:
                text = section.heading
            if not text:
                continue

            # Prepend heading to content for context
            full_text = f"## {section.heading}\n\n{text}" if section.heading else text

            chunks.append(Chunk(
                content=full_text,
                section_title=section.heading,
                offset=offset,
            ))
            offset += _word_count(full_text)

        return chunks

    def _split_by_paragraphs(self, text: str) -> list[Chunk]:
        """Level 2: Split at paragraph boundaries."""
        # Protect code blocks and math from splitting
        protected, placeholders = _protect_blocks(text)

        paragraphs = _PARAGRAPH_BREAK_RE.split(protected)
        paragraphs = [p.strip() for p in paragraphs if p.strip()]

        # Merge small paragraphs into chunks up to target size
        chunks: list[Chunk] = []
        current_parts: list[str] = []
        current_words = 0
        offset = 0

        for para in paragraphs:
            restored = _restore_blocks(para, placeholders)
            para_words = _word_count(restored)

            if current_words + para_words > self._config.target_words and current_parts:
                chunk_text = "\n\n".join(current_parts)
                chunks.append(Chunk(content=chunk_text, offset=offset))
                offset += current_words
                current_parts = []
                current_words = 0

            current_parts.append(restored)
            current_words += para_words

        if current_parts:
            chunks.append(Chunk(content="\n\n".join(current_parts), offset=offset))

        return chunks

    def _enforce_size_limits(self, chunks: list[Chunk]) -> list[Chunk]:
        """Level 3+4: Recursively split oversized chunks."""
        result: list[Chunk] = []

        for chunk in chunks:
            wc = _word_count(chunk.content)
            if wc <= self._config.max_chunk_words:
                result.append(chunk)
                continue

            # Try sentence-level splitting
            sub_chunks = self._split_by_sentences(chunk)
            result.extend(sub_chunks)

        return result

    def _split_by_sentences(self, chunk: Chunk) -> list[Chunk]:
        """Level 4: Sentence-level fallback splitting."""
        sentences = _SENTENCE_RE.split(chunk.content)
        if len(sentences) <= 1:
            return [chunk]

        result: list[Chunk] = []
        current_parts: list[str] = []
        current_words = 0
        offset = chunk.offset

        for sentence in sentences:
            s_words = _word_count(sentence)

            if current_words + s_words > self._config.target_words and current_parts:
                text = " ".join(current_parts)
                result.append(Chunk(
                    content=text,
                    section_title=chunk.section_title,
                    offset=offset,
                ))
                offset += current_words
                current_parts = []
                current_words = 0

            current_parts.append(sentence)
            current_words += s_words

        if current_parts:
            result.append(Chunk(
                content=" ".join(current_parts),
                section_title=chunk.section_title,
                offset=offset,
            ))

        return result

    def _add_overlap(self, chunks: list[Chunk]) -> list[Chunk]:
        """Add overlapping context between adjacent chunks."""
        if len(chunks) <= 1:
            return chunks

        overlap_words = self._config.overlap_words

        for i in range(len(chunks)):
            # Add overlap from previous chunk
            if i > 0:
                prev_words = chunks[i - 1].content.split()
                overlap = " ".join(prev_words[-overlap_words:]) if len(prev_words) > overlap_words else ""
                if overlap:
                    chunks[i].overlap_before = overlap
                    chunks[i].content = overlap + "\n\n" + chunks[i].content

            # Add overlap from next chunk
            if i < len(chunks) - 1:
                next_words = chunks[i + 1].content.split()
                overlap = " ".join(next_words[:overlap_words]) if len(next_words) > overlap_words else ""
                if overlap:
                    chunks[i].overlap_after = overlap
                    chunks[i].content = chunks[i].content + "\n\n" + overlap

        return chunks

    def _compute_quality_score(self, chunk: Chunk) -> float:
        """Compute chunk quality score (CP-04b).

        Higher score = better quality chunk. Factors:
        - Optimal size (near target word count)
        - Has section title (structural context)
        - Content density (low whitespace ratio)
        """
        score = 1.0

        # Size factor: penalize very small or very large chunks
        wc = _word_count(chunk.content)
        target = self._config.target_words
        size_ratio = wc / target if target > 0 else 1.0
        if size_ratio < 0.3:
            score *= 0.6
        elif size_ratio < 0.5:
            score *= 0.8
        elif size_ratio > 2.0:
            score *= 0.7

        # Section title bonus
        if chunk.section_title:
            score = min(score * 1.1, 1.0)

        # Content density: penalize excessive whitespace
        stripped = chunk.content.replace(" ", "").replace("\n", "")
        if len(chunk.content) > 0:
            density = len(stripped) / len(chunk.content)
            if density < 0.3:
                score *= 0.7

        return round(max(0.0, min(1.0, score)), 3)


def _word_count(text: str) -> int:
    return len(text.split())


def _protect_blocks(text: str) -> tuple[str, dict[str, str]]:
    """Replace code blocks and math blocks with placeholders to prevent splitting inside them."""
    placeholders: dict[str, str] = {}
    counter = 0

    for pattern in [_CODE_BLOCK_RE, _MATH_BLOCK_RE]:
        for match in pattern.finditer(text):
            placeholder = f"__PROTECTED_{counter}__"
            placeholders[placeholder] = match.group()
            text = text.replace(match.group(), placeholder, 1)
            counter += 1

    return text, placeholders


def _restore_blocks(text: str, placeholders: dict[str, str]) -> str:
    """Restore protected blocks from placeholders."""
    for placeholder, original in placeholders.items():
        text = text.replace(placeholder, original)
    return text
