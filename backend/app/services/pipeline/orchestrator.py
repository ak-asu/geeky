"""Pipeline orchestrator — coordinates the full content processing pipeline.

Pipeline: parse → chunk → dedup → embed → store vectors → generate shorts → save.

Tracks per-stage status in ProcessingTask. Handles errors gracefully per
stage (CP-14). Enforces anti-density controls (CP-17).
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from app.config import Settings
from app.models.chunk import ChunkDocument
from app.models.common import ProcessingStatus
from app.models.short import ConflictFlag, ShortDocument
from app.services.pipeline.chunker import ChunkerConfig, HierarchicalChunker
from app.services.pipeline.deduplicator import DedupConfig, Deduplicator
from app.services.pipeline.short_generator import ShortGenerator

logger = logging.getLogger(__name__)

# Pipeline stages in order
STAGES = ["extraction", "chunking", "deduplication", "embedding", "short_generation", "storage"]


class PipelineOrchestrator:
    """Coordinates the full note processing pipeline.

    All dependencies are injected via constructor.
    """

    def __init__(
        self,
        *,
        document_parser,
        embedding_provider,
        vector_store,
        llm_provider,
        note_repo,
        chunk_repo,
        short_repo,
        processing_task_repo,
        settings: Settings,
    ) -> None:
        self._parser = document_parser
        self._embedder = embedding_provider
        self._vector_store = vector_store
        self._llm = llm_provider
        self._note_repo = note_repo
        self._chunk_repo = chunk_repo
        self._short_repo = short_repo
        self._task_repo = processing_task_repo
        self._settings = settings

        self._chunker = HierarchicalChunker(ChunkerConfig(
            target_words=settings.chunk_target_words,
            overlap_words=settings.chunk_overlap_words,
        ))
        self._deduplicator = Deduplicator(
            vector_store=vector_store,
            embedding_provider=embedding_provider,
            config=DedupConfig(
                near_threshold=settings.dedup_near_threshold,
                semantic_threshold=settings.dedup_semantic_threshold,
            ),
        )
        self._short_generator = ShortGenerator(llm=llm_provider)

    async def process(self, user_id: str, note_id: str, task_id: str) -> dict:
        """Execute the full processing pipeline for a note.

        Args:
            user_id: Owner of the note.
            note_id: Note to process.
            task_id: ProcessingTask ID for status tracking.

        Returns:
            Summary dict with counts of chunks and shorts created.
        """
        logger.info("Starting pipeline for note=%s user=%s task=%s", note_id, user_id, task_id)

        try:
            await self._update_task_status(task_id, ProcessingStatus.PROCESSING)

            # Stage 1: Extraction
            note = await self._stage_extraction(user_id, note_id, task_id)

            # Stage 2: Chunking
            chunks = await self._stage_chunking(note.content, note.extracted_text, task_id)

            # Stage 3: Deduplication
            dedup_results = await self._stage_deduplication(chunks, user_id, task_id)

            # Keep only non-duplicate chunks
            kept_chunks = [r.chunk for r in dedup_results if not r.is_duplicate]
            canonical_map = {
                r.chunk.hash_sha256: r.canonical_chunk_id
                for r in dedup_results
                if r.is_soft_duplicate and r.canonical_chunk_id
            }

            if not kept_chunks:
                logger.warning("All chunks were duplicates for note=%s", note_id)
                await self._complete_stage(task_id, "embedding")
                await self._complete_stage(task_id, "short_generation")
                await self._complete_stage(task_id, "storage")
                await self._update_task_status(task_id, ProcessingStatus.COMPLETED)
                await self._note_repo.update(user_id, note_id, {"processed": True})
                return {"chunks_created": 0, "shorts_created": 0}

            # Stage 4: Embedding
            chunk_ids, chunk_docs = await self._stage_embedding(
                kept_chunks, canonical_map, user_id, note_id, task_id
            )

            # Stage 5: Short generation
            short_ids, shorts_created = await self._stage_short_generation(
                kept_chunks, chunk_ids, user_id, note_id, task_id
            )

            # Stage 6: Storage — finalize note as processed
            await self._start_stage(task_id, "storage")
            await self._note_repo.update(user_id, note_id, {
                "processed": True,
                "wordCount": sum(c.word_count for c in kept_chunks),
            })
            await self._complete_stage(task_id, "storage")

            await self._update_task_status(task_id, ProcessingStatus.COMPLETED)

            # Dispatch KG update + review state creation for new shorts
            if shorts_created > 0:
                self._dispatch_post_pipeline_tasks(user_id, short_ids, shorts_created)

            summary = {"chunks_created": len(chunk_ids), "shorts_created": shorts_created}
            logger.info("Pipeline completed for note=%s: %s", note_id, summary)
            return summary

        except Exception as exc:
            logger.error("Pipeline failed for note=%s: %s", note_id, exc, exc_info=True)
            await self._update_task_status(task_id, ProcessingStatus.FAILED, error=str(exc))
            raise

    async def _stage_extraction(self, user_id: str, note_id: str, task_id: str):
        """Stage 1: Fetch note and parse content."""
        await self._start_stage(task_id, "extraction")

        note = await self._note_repo.get(user_id, note_id)
        if note is None:
            from app.exceptions import NoteNotFoundError  # noqa: PLC0415
            raise NoteNotFoundError(note_id)

        # If note has file content to extract, parse it
        if note.type.value != "text" and note.content:
            try:
                parsed = await self._parser.parse(
                    content=note.content.encode("utf-8"),
                    content_type=_note_type_to_content_type(note.type.value),
                )
                await self._note_repo.update(user_id, note_id, {
                    "extractedText": parsed.text,
                    "primaryTopic": parsed.title,
                })
                note.extracted_text = parsed.text
            except Exception as exc:
                logger.warning("Extraction failed for note=%s: %s", note_id, exc)
                # CP-14: Continue with raw content
                note.extracted_text = note.content

        await self._complete_stage(task_id, "extraction")
        return note

    async def _stage_chunking(self, content: str, extracted_text: str | None, task_id: str):
        """Stage 2: Chunk the text content."""
        await self._start_stage(task_id, "chunking")

        text = extracted_text or content
        from app.services.pipeline.extractor.base import ParsedDocument  # noqa: PLC0415
        doc = ParsedDocument(text=text)
        chunks = self._chunker.chunk(doc)

        await self._complete_stage(task_id, "chunking")
        return chunks

    async def _stage_deduplication(self, chunks, user_id: str, task_id: str):
        """Stage 3: Run deduplication pipeline."""
        await self._start_stage(task_id, "deduplication")

        results = await self._deduplicator.deduplicate(chunks, user_id)

        await self._complete_stage(task_id, "deduplication")
        return results

    async def _stage_embedding(
        self, chunks, canonical_map, user_id, note_id, task_id
    ):
        """Stage 4: Embed chunks and store in vector DB + Firestore."""
        await self._start_stage(task_id, "embedding")

        texts = [c.content for c in chunks]
        embeddings = await self._embedder.embed_texts(texts)

        chunk_ids: list[str] = []
        chunk_docs: list[ChunkDocument] = []

        for i, chunk in enumerate(chunks):
            chunk_id = str(uuid.uuid4())
            chunk_ids.append(chunk_id)

            doc = ChunkDocument(
                id=chunk_id,
                note_id=note_id,
                content=chunk.content,
                section_title=chunk.section_title,
                offset=chunk.offset,
                token_span=chunk.word_count,
                quality_score=chunk.quality_score,
                hash_sha256=chunk.hash_sha256,
                canonical_chunk_id=canonical_map.get(chunk.hash_sha256),
                dedup_log=None,
            )
            chunk_docs.append(doc)

            # Save chunk to Firestore
            await self._chunk_repo.create(user_id, doc, doc_id=chunk_id)

        # Store embeddings in vector DB
        metadatas = [
            {
                "note_id": note_id,
                "chunk_id": chunk_ids[i],
                "section_title": chunks[i].section_title or "",
                "offset": chunks[i].offset,
                "quality_score": chunks[i].quality_score,
            }
            for i in range(len(chunks))
        ]

        await self._vector_store.add(
            ids=chunk_ids,
            embeddings=embeddings,
            documents=texts,
            metadatas=metadatas,
            user_id=user_id,
        )

        await self._complete_stage(task_id, "embedding")
        return chunk_ids, chunk_docs

    async def _stage_short_generation(
        self, chunks, chunk_ids, user_id, note_id, task_id
    ):
        """Stage 5: Generate Shorts from chunks."""
        await self._start_stage(task_id, "short_generation")

        # CP-17: Anti-density control — find shorts already linked to this note
        existing_chunk_docs = await self._chunk_repo.get_by_note(user_id, note_id)
        existing_chunk_ids = [c.id for c in existing_chunk_docs]
        existing_shorts = (
            await self._short_repo.get_by_chunk_ids(user_id, existing_chunk_ids)
            if existing_chunk_ids
            else []
        )
        if len(existing_shorts) >= self._settings.anti_density_max_per_source:
            logger.warning(
                "Anti-density limit reached for note=%s (%d/%d)",
                note_id, len(existing_shorts), self._settings.anti_density_max_per_source,
            )
            await self._complete_stage(task_id, "short_generation")
            return [], 0

        max_new = self._settings.anti_density_max_per_source - len(existing_shorts)
        chunks_to_process = chunks[:max_new]

        generated = await self._short_generator.generate(
            chunks_to_process,
            note_id=note_id,
        )

        # Detect conflicts
        conflicts = await self._short_generator.detect_conflicts(generated)

        created_short_ids: list[str] = []
        for i, gen_short in enumerate(generated):
            short_id = str(uuid.uuid4())

            conflict_flags = []
            for a, b, claim in conflicts:
                if a == i or b == i:
                    conflict_flags.append(ConflictFlag(claim=claim, sources=[note_id]))

            short_doc = ShortDocument(
                id=short_id,
                user_id=user_id,
                title=gen_short.title,
                content=gen_short.summary,
                summary=gen_short.summary,
                topics=gen_short.topics,
                tags=gen_short.tags,
                prerequisites=gen_short.prerequisites,
                citations=[note_id],
                difficulty=gen_short.difficulty,
                prompts=gen_short.prompts,
                chunk_ids=[chunk_ids[i]] if i < len(chunk_ids) else [],
                conflict_flags=conflict_flags,
            )

            await self._short_repo.create(user_id, short_doc, doc_id=short_id)
            created_short_ids.append(short_id)

        await self._complete_stage(task_id, "short_generation")
        return created_short_ids, len(created_short_ids)

    # --- Task status helpers ---

    async def _update_task_status(
        self, task_id: str, status: ProcessingStatus, error: str | None = None
    ) -> None:
        await self._task_repo.update_status(task_id, status.value, error=error)

    async def _start_stage(self, task_id: str, stage: str) -> None:
        await self._task_repo.update_stage(task_id, stage, {
            "status": ProcessingStatus.PROCESSING.value,
            "startedAt": datetime.now(timezone.utc).isoformat(),
        })

    async def _complete_stage(self, task_id: str, stage: str) -> None:
        await self._task_repo.update_stage(task_id, stage, {
            "status": ProcessingStatus.COMPLETED.value,
            "completedAt": datetime.now(timezone.utc).isoformat(),
        })

    async def _fail_stage(self, task_id: str, stage: str, error: str) -> None:
        await self._task_repo.update_stage(task_id, stage, {
            "status": ProcessingStatus.FAILED.value,
            "error": error,
            "completedAt": datetime.now(timezone.utc).isoformat(),
        })

    def _dispatch_post_pipeline_tasks(
        self, user_id: str, short_ids: list[str], shorts_created: int
    ) -> None:
        """Dispatch KG update and review state creation after pipeline completes."""
        try:
            from app.workers.kg_tasks import (  # noqa: PLC0415
                ensure_review_states,
                update_kg_for_short,
            )
            from app.workers.quiz_tasks import generate_quiz_for_short  # noqa: PLC0415

            for short_id in short_ids[:shorts_created]:
                update_kg_for_short.delay(user_id, short_id)
                generate_quiz_for_short.delay(user_id, short_id)

            ensure_review_states.delay(user_id, short_ids[:shorts_created])

            logger.info(
                "Dispatched KG update + quiz + review state tasks for %d shorts",
                shorts_created,
            )
        except Exception as exc:
            # Non-fatal: pipeline succeeded, post-tasks can be retried independently
            logger.warning("Failed to dispatch post-pipeline tasks: %s", exc)


def _note_type_to_content_type(note_type: str) -> str:
    """Map NoteType to content MIME type for the parser."""
    mapping = {
        "text": "text/plain",
        "image": "image/png",
        "audio": "audio/mpeg",
        "link": "text/html",
        "video": "video/mp4",
        "file": "application/pdf",
    }
    return mapping.get(note_type, "text/plain")
