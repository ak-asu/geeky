"""RAG orchestrator — full retrieval-augmented generation pipeline.

Pipeline: hybrid search → rerank → MMR diversity pruning → context
assembly → LLM generation → citation tracking.

Supports multiple modes: QA, study guide, mind map, outline (RQ-03, RQ-08).
"""

from __future__ import annotations

import logging
import math
from typing import Any

from app.config import Settings
from app.exceptions import RAGError
from app.models.common import RAGMode
from app.models.rag import RAGCitation, RAGQueryRequest, RAGQueryResponse

logger = logging.getLogger(__name__)


# Mode-specific system prompts
_SYSTEM_PROMPTS: dict[RAGMode, str] = {
    RAGMode.QA: (
        "You are a helpful study assistant. Answer the user's question using ONLY "
        "the provided context. If the context doesn't contain enough information, "
        "say so clearly. Cite sources using [1], [2], etc. matching the context order."
    ),
    RAGMode.STUDY_GUIDE: (
        "You are a study guide generator. Create a comprehensive study guide from "
        "the provided context. Organize by topic with key concepts, definitions, and "
        "examples. Use clear headings and bullet points. Cite sources using [1], [2], etc."
    ),
    RAGMode.MIND_MAP: (
        "You are a mind map generator. Create a hierarchical mind map structure from "
        "the provided context. Return a JSON object with 'central_topic' (string) and "
        "'branches' (array of objects with 'topic', 'subtopics' array). Cite sources."
    ),
    RAGMode.OUTLINE: (
        "You are an outline generator. Create a structured outline from the provided "
        "context with numbered sections and subsections. Include key points under each "
        "section. Cite sources using [1], [2], etc."
    ),
}


def _estimate_tokens(text: str) -> int:
    """Approximate token count from word count (1 word ≈ 1.3 tokens)."""
    return int(len(text.split()) * 1.3)


def _cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two vectors."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


class RAGOrchestrator:
    """Full RAG pipeline orchestrator.

    Args:
        search_service: Hybrid search for retrieval.
        reranker: Cross-encoder reranker (Reranker Protocol).
        llm: LLM provider for generation (LLMProvider Protocol).
        embedding_provider: For MMR diversity computation (EmbeddingProvider Protocol).
        short_repo: Repository for fetching short content.
        settings: Application settings.
    """

    def __init__(
        self,
        *,
        search_service: Any,  # HybridSearchService
        reranker: Any,  # Reranker Protocol
        llm: Any,  # LLMProvider Protocol
        embedding_provider: Any,  # EmbeddingProvider Protocol
        short_repo: Any,  # ShortRepository
        settings: Settings,
    ) -> None:
        self._search = search_service
        self._reranker = reranker
        self._llm = llm
        self._embedder = embedding_provider
        self._short_repo = short_repo
        self._settings = settings

    async def query(
        self, user_id: str, request: RAGQueryRequest
    ) -> RAGQueryResponse:
        """Execute the full RAG pipeline.

        Stages:
        1. Retrieve — hybrid search for candidates
        2. Rerank — cross-encoder scoring
        3. MMR Diversity — prune redundant contexts (RQ-08)
        4. Context Assembly — build prompt within token budget
        5. Generate — LLM call with mode-specific prompt
        6. Citations — track source attribution (RQ-03)
        """
        try:
            # Stage 1: Retrieve
            candidates = await self._retrieve(user_id, request)
            if not candidates:
                return RAGQueryResponse(
                    answer="I couldn't find any relevant content in your notes to answer this question.",
                    citations=[],
                    follow_up_questions=[],
                )

            # Stage 2: Rerank
            reranked = await self._rerank(request.question, candidates)
            if not reranked:
                return RAGQueryResponse(
                    answer="I couldn't find sufficiently relevant content to answer this question.",
                    citations=[],
                    follow_up_questions=[],
                )

            # Stage 3: MMR Diversity Pruning
            diverse = await self._mmr_prune(reranked)

            # Stage 4: Context Assembly
            context_blocks, citations = self._assemble_context(diverse)
            if not context_blocks:
                return RAGQueryResponse(
                    answer="The retrieved content was too short to provide a meaningful answer.",
                    citations=[],
                    follow_up_questions=[],
                )

            # Stage 5: Generate
            answer = await self._generate(request.question, request.mode, context_blocks)

            # Stage 6: Build response with citations
            follow_ups = self._extract_follow_ups(answer, request.mode)

            response = RAGQueryResponse(
                answer=answer,
                citations=citations,
                follow_up_questions=follow_ups,
            )

            # For mind map mode, try to parse structured output
            if request.mode == RAGMode.MIND_MAP:
                response.mind_map = self._try_parse_mind_map(answer)

            return response

        except RAGError:
            raise
        except Exception as exc:
            logger.error("RAG pipeline failed: %s", exc)
            raise RAGError(f"RAG pipeline error: {exc}") from exc

    async def _retrieve(
        self, user_id: str, request: RAGQueryRequest
    ) -> list[dict]:
        """Stage 1: Hybrid search for candidate documents."""
        top_k = request.top_k or self._settings.rag_top_k
        search_results = await self._search.search(
            user_id, request.question, top_k=top_k * 2
        )

        candidates = []
        for result in search_results:
            short = await self._short_repo.get(user_id, result.short_id)
            if short:
                candidates.append({
                    "short_id": short.id,
                    "title": short.title,
                    "content": short.content,
                    "topics": short.topics,
                })

        logger.info("Retrieved %d candidates for query: %s", len(candidates), request.question[:80])
        return candidates

    async def _rerank(
        self, query: str, candidates: list[dict]
    ) -> list[dict]:
        """Stage 2: Cross-encoder reranking."""
        if not candidates:
            return []

        documents = [c["content"] for c in candidates]
        doc_ids = [c["short_id"] for c in candidates]

        ranked = await self._reranker.rerank(
            query=query,
            documents=documents,
            document_ids=doc_ids,
            top_k=self._settings.rag_top_k,
        )

        # Map back to candidate dicts preserving rerank order
        id_to_candidate = {c["short_id"]: c for c in candidates}
        reranked = []
        for r in ranked:
            if r.document_id in id_to_candidate:
                candidate = id_to_candidate[r.document_id]
                candidate["rerank_score"] = r.score
                reranked.append(candidate)

        return reranked

    async def _mmr_prune(self, candidates: list[dict]) -> list[dict]:
        """Stage 3: Maximal Marginal Relevance diversity pruning (RQ-08).

        Greedily select documents that are relevant but dissimilar to
        already-selected documents.
        """
        if len(candidates) <= 2:
            return candidates

        # Embed all candidate contents
        texts = [c["content"] for c in candidates]
        embeddings = await self._embedder.embed_texts(texts)

        mmr_lambda = self._settings.rag_mmr_lambda
        redundancy_threshold = self._settings.rag_redundancy_threshold

        selected: list[int] = [0]  # Start with highest-ranked
        selected_embeddings = [embeddings[0]]

        for i in range(1, len(candidates)):
            emb = embeddings[i]

            # Max similarity to any already-selected document
            max_sim = max(
                _cosine_similarity(emb, sel_emb)
                for sel_emb in selected_embeddings
            )

            # Skip if too redundant
            if max_sim > redundancy_threshold:
                continue

            # MMR score: λ * relevance - (1-λ) * max_similarity
            relevance = candidates[i].get("rerank_score", 0.0)
            mmr_score = mmr_lambda * relevance - (1 - mmr_lambda) * max_sim

            if mmr_score > 0 or len(selected) < 3:
                selected.append(i)
                selected_embeddings.append(emb)

        return [candidates[i] for i in selected]

    def _assemble_context(
        self, candidates: list[dict]
    ) -> tuple[list[str], list[RAGCitation]]:
        """Stage 4: Assemble context blocks within token budget."""
        max_tokens = self._settings.rag_context_max_tokens
        blocks = []
        citations = []
        total_tokens = 0

        for i, candidate in enumerate(candidates):
            content = candidate["content"]
            tokens = _estimate_tokens(content)

            if total_tokens + tokens > max_tokens and blocks:
                break

            block = f"[{i + 1}] {candidate['title']}\n{content}"
            blocks.append(block)
            total_tokens += tokens

            citations.append(
                RAGCitation(
                    short_id=candidate["short_id"],
                    title=candidate["title"],
                    snippet=content[:200],
                )
            )

        return blocks, citations

    async def _generate(
        self, question: str, mode: RAGMode, context_blocks: list[str]
    ) -> str:
        """Stage 5: LLM generation with mode-specific prompt."""
        system = _SYSTEM_PROMPTS.get(mode, _SYSTEM_PROMPTS[RAGMode.QA])
        context = "\n\n---\n\n".join(context_blocks)

        prompt = f"""Context:
{context}

Question: {question}

Please provide a thorough answer based on the context above."""

        answer = await self._llm.generate(
            prompt,
            system=system,
            temperature=0.3,
            max_tokens=2000,
        )

        return answer.strip()

    def _extract_follow_ups(self, answer: str, mode: RAGMode) -> list[str]:
        """Generate follow-up question suggestions based on the answer."""
        # Simple heuristic: extract topics mentioned in the answer
        # A more sophisticated version would use the LLM
        if mode == RAGMode.MIND_MAP:
            return []
        return []

    def _try_parse_mind_map(self, answer: str) -> dict | None:
        """Try to parse mind map JSON from the answer."""
        import json  # noqa: PLC0415

        # Try to find JSON in the answer
        try:
            # Look for JSON block
            start = answer.find("{")
            end = answer.rfind("}") + 1
            if start >= 0 and end > start:
                return json.loads(answer[start:end])
        except (json.JSONDecodeError, ValueError):
            pass
        return None
