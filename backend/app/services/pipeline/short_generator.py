"""Short generator — CP-07 through CP-11, CP-15, CP-16, CP-24.

Uses LLMProvider to generate one Short per chunk:
- 150–250 word summary (CP-07)
- 5–10 exploration questions (CP-11)
- Difficulty score 0.0–1.0 (CP-10)
- Topic extraction (CP-09)
- Conflict detection between chunks (CP-16)
- Generation-time dedup via coverage constraints (CP-24)
"""

from __future__ import annotations

import logging

from pydantic import BaseModel, Field

from app.services.pipeline.chunker import Chunk

logger = logging.getLogger(__name__)

# Structured output models for Gemini


class GeneratedShort(BaseModel):
    """Structured output from the LLM for a single Short."""

    title: str = ""
    summary: str = ""
    topics: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    difficulty: float = 0.5
    prompts: list[str] = Field(default_factory=list)
    prerequisites: list[str] = Field(default_factory=list)
    conflict_claims: list[str] = Field(default_factory=list)


_SYSTEM_PROMPT = """You are an expert educational content creator for the Geeky learning platform.
Your job is to transform text chunks into concise, engaging "Shorts" — bite-sized learning cards.

Rules:
- The summary MUST be 150–250 words, focused on a single concept
- Extract 3–5 specific topics/tags from the content
- Generate 5–10 exploration questions that encourage deeper learning
- Assess difficulty from 0.0 (beginner) to 1.0 (expert)
- Identify any prerequisite concepts needed to understand this content
- If the content contains conflicting claims or controversial statements, list them
- Use clear, accessible language appropriate for the difficulty level
- Ground all statements in the source content — do NOT hallucinate facts
- NEVER include information not present in the source chunk"""

_GENERATION_PROMPT = """Transform the following text chunk into a structured learning Short.

Source chunk (from section: "{section_title}"):
---
{chunk_content}
---

{coverage_constraint}

Generate the Short as a JSON object with these fields:
- title: A concise, descriptive title (5-10 words)
- summary: A 150-250 word educational summary of the key concept
- topics: 3-5 topic tags (lowercase, hyphenated)
- tags: Additional metadata tags
- difficulty: Float 0.0-1.0 (0=beginner, 1=expert)
- prompts: 5-10 exploration questions for deeper learning
- prerequisites: Prerequisite concepts (if any)
- conflict_claims: Any conflicting claims found (empty list if none)"""


class ShortGenerator:
    """Generates Shorts from chunks using an LLM provider.

    Args:
        llm: LLMProvider implementation (injected).
    """

    def __init__(self, llm) -> None:
        self._llm = llm

    async def generate(
        self,
        chunks: list[Chunk],
        *,
        note_id: str,
        existing_topics: list[str] | None = None,
    ) -> list[GeneratedShort]:
        """Generate one Short per chunk.

        Args:
            chunks: List of text chunks to summarize.
            note_id: Source note ID for citation tracking.
            existing_topics: Topics already covered (for CP-24 coverage constraints).

        Returns:
            List of GeneratedShort objects (one per chunk).
        """
        if not chunks:
            return []

        covered_topics: set[str] = set(existing_topics or [])
        results: list[GeneratedShort] = []

        for chunk in chunks:
            try:
                short = await self._generate_single(chunk, covered_topics)
                results.append(short)
                covered_topics.update(short.topics)
            except Exception as exc:
                logger.error("Failed to generate Short for chunk at offset %d: %s", chunk.offset, exc)
                # CP-14: Skip unprocessable chunks, continue with rest
                results.append(GeneratedShort(
                    title=f"Untitled ({chunk.section_title or 'section'})",
                    summary=chunk.content[:250] + "..." if len(chunk.content) > 250 else chunk.content,
                    topics=[],
                    difficulty=0.5,
                    prompts=["What are the key concepts in this section?"],
                ))

        logger.info("Generated %d Shorts from %d chunks", len(results), len(chunks))
        return results

    async def _generate_single(
        self,
        chunk: Chunk,
        covered_topics: set[str],
    ) -> GeneratedShort:
        """Generate a single Short from a chunk."""
        # CP-24: Coverage constraint to avoid repetition
        coverage_constraint = ""
        if covered_topics:
            topics_str = ", ".join(sorted(covered_topics)[:20])
            coverage_constraint = (
                f"IMPORTANT: The following topics have already been covered by other Shorts. "
                f"Focus on NEW information not covered by these topics: {topics_str}"
            )

        prompt = _GENERATION_PROMPT.format(
            section_title=chunk.section_title or "Unknown",
            chunk_content=chunk.content[:4000],  # Token budget
            coverage_constraint=coverage_constraint,
        )

        short = await self._llm.generate_structured(
            prompt=prompt,
            response_model=GeneratedShort,
            system=_SYSTEM_PROMPT,
            temperature=0.3,
        )

        return short

    async def detect_conflicts(
        self,
        shorts: list[GeneratedShort],
    ) -> list[tuple[int, int, str]]:
        """Detect conflicts between generated Shorts (CP-16).

        Returns list of (short_idx_a, short_idx_b, conflicting_claim).
        """
        conflicts: list[tuple[int, int, str]] = []

        for i, short_a in enumerate(shorts):
            if not short_a.conflict_claims:
                continue
            for j, short_b in enumerate(shorts):
                if j <= i:
                    continue
                # Check for overlapping conflict claims
                for claim in short_a.conflict_claims:
                    if any(claim.lower() in bc.lower() or bc.lower() in claim.lower()
                           for bc in short_b.conflict_claims):
                        conflicts.append((i, j, claim))

        return conflicts
