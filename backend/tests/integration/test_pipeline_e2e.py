"""End-to-end integration tests for the content processing pipeline.

Tests the full pipeline with all mocks: parse → chunk → dedup → embed
→ store vectors → generate shorts → save to Firestore.
"""

from __future__ import annotations

import pytest

from app.config import Settings
from app.models.common import ProcessingStatus
from app.models.note import NoteDocument
from app.models.processing_task import ProcessingTaskDocument
from app.services.pipeline.orchestrator import PipelineOrchestrator
from tests.mocks.mock_embedder import MockEmbeddingProvider
from tests.mocks.mock_firebase import MockFirestoreClient
from tests.mocks.mock_llm import MockLLMProvider
from tests.mocks.mock_vector_store import MockVectorStore

_TEST_USER = "test-user-pipeline"


class MockDocumentParser:
    """Minimal mock parser for pipeline tests."""

    async def parse(self, content, content_type, filename=None):
        from app.services.pipeline.extractor.base import ParsedDocument

        return ParsedDocument(text=content.decode("utf-8", errors="replace"))

    def supported_types(self):
        return ["text/plain"]


class MockProcessingTaskRepo:
    """In-memory processing task repository for testing."""

    def __init__(self):
        self._tasks: dict[str, dict] = {}

    async def get(self, task_id):
        data = self._tasks.get(task_id)
        if not data:
            return None
        return ProcessingTaskDocument.model_validate({**data, "id": task_id})

    async def create(self, data):
        from uuid import uuid4

        task_id = str(uuid4())
        self._tasks[task_id] = data.model_dump(mode="json")
        return task_id

    async def update_status(self, task_id, status, error=None):
        if task_id in self._tasks:
            self._tasks[task_id]["status"] = status
            if error:
                self._tasks[task_id]["error"] = error

    async def update_stage(self, task_id, stage, stage_status):
        if task_id in self._tasks:
            if "stages" not in self._tasks[task_id]:
                self._tasks[task_id]["stages"] = {}
            self._tasks[task_id]["stages"][stage] = stage_status


class MockNoteRepo:
    """In-memory note repository for testing."""

    def __init__(self):
        self._notes: dict[str, dict] = {}

    async def get(self, user_id, note_id):
        key = f"{user_id}/{note_id}"
        data = self._notes.get(key)
        if not data:
            return None
        return NoteDocument.model_validate({**data, "id": note_id})

    async def create(self, user_id, data, doc_id=None):
        from uuid import uuid4

        note_id = doc_id or str(uuid4())
        self._notes[f"{user_id}/{note_id}"] = data.model_dump(mode="json")
        return note_id

    async def update(self, user_id, note_id, data):
        key = f"{user_id}/{note_id}"
        if key in self._notes:
            self._notes[key].update(data)


class MockChunkRepo:
    """In-memory chunk repository for testing."""

    def __init__(self):
        self._chunks: dict[str, dict] = {}

    async def create(self, user_id, data, doc_id=None):
        from uuid import uuid4

        chunk_id = doc_id or str(uuid4())
        self._chunks[f"{user_id}/{chunk_id}"] = data.model_dump(mode="json")
        return chunk_id

    async def get_by_note(self, user_id, note_id):
        return []

    async def delete_by_note(self, user_id, note_id):
        return 0


class MockShortRepo:
    """In-memory short repository for testing."""

    def __init__(self):
        self._shorts: dict[str, dict] = {}

    async def create(self, user_id, data, doc_id=None):
        from uuid import uuid4

        short_id = doc_id or str(uuid4())
        self._shorts[f"{user_id}/{short_id}"] = data.model_dump(mode="json", by_alias=True)
        return short_id

    async def query(self, user_id, filters=None, limit=50):
        return []


@pytest.fixture
def mock_deps():
    """Create all mock dependencies for the orchestrator."""
    return {
        "document_parser": MockDocumentParser(),
        "embedding_provider": MockEmbeddingProvider(dimensions=768),
        "vector_store": MockVectorStore(),
        "llm_provider": MockLLMProvider(),
        "note_repo": MockNoteRepo(),
        "chunk_repo": MockChunkRepo(),
        "short_repo": MockShortRepo(),
        "processing_task_repo": MockProcessingTaskRepo(),
        "settings": Settings(
            chunk_target_words=50,
            chunk_overlap_words=10,
            anti_density_max_per_source=50,
        ),
    }


@pytest.fixture
async def seeded_pipeline(mock_deps):
    """Set up a pipeline with a note already created."""
    note_repo = mock_deps["note_repo"]
    task_repo = mock_deps["processing_task_repo"]

    note = NoteDocument(
        type="text",
        title="Test Note",
        content=(
            "Machine learning is a branch of artificial intelligence. "
            "It involves algorithms that learn from data. "
            "Deep learning is a subset of machine learning. "
            "Neural networks are used in deep learning. "
            "Supervised learning uses labeled data. "
            "Unsupervised learning finds patterns in unlabeled data. "
            "Reinforcement learning uses rewards and penalties. "
            "Natural language processing deals with text data. "
            "Computer vision processes image data. "
            "Transfer learning reuses models across tasks."
        ),
        processed=False,
    )
    note_id = await note_repo.create(_TEST_USER, note, doc_id="test-note-1")

    task = ProcessingTaskDocument(
        user_id=_TEST_USER,
        note_id=note_id,
        status=ProcessingStatus.PENDING,
    )
    task_id = await task_repo.create(task)

    return note_id, task_id


class TestFullPipeline:
    @pytest.mark.asyncio
    async def test_pipeline_completes(self, mock_deps, seeded_pipeline):
        note_id, task_id = seeded_pipeline

        orchestrator = PipelineOrchestrator(**mock_deps)
        result = await orchestrator.process(_TEST_USER, note_id, task_id)

        assert "chunks_created" in result
        assert "shorts_created" in result
        assert result["chunks_created"] >= 1
        assert result["shorts_created"] >= 1

    @pytest.mark.asyncio
    async def test_pipeline_marks_note_processed(self, mock_deps, seeded_pipeline):
        note_id, task_id = seeded_pipeline

        orchestrator = PipelineOrchestrator(**mock_deps)
        await orchestrator.process(_TEST_USER, note_id, task_id)

        note = await mock_deps["note_repo"].get(_TEST_USER, note_id)
        assert note.processed is True

    @pytest.mark.asyncio
    async def test_pipeline_updates_task_status(self, mock_deps, seeded_pipeline):
        note_id, task_id = seeded_pipeline

        orchestrator = PipelineOrchestrator(**mock_deps)
        await orchestrator.process(_TEST_USER, note_id, task_id)

        task = await mock_deps["processing_task_repo"].get(task_id)
        assert task.status == ProcessingStatus.COMPLETED

    @pytest.mark.asyncio
    async def test_pipeline_creates_chunks_in_firestore(self, mock_deps, seeded_pipeline):
        note_id, task_id = seeded_pipeline

        orchestrator = PipelineOrchestrator(**mock_deps)
        result = await orchestrator.process(_TEST_USER, note_id, task_id)

        chunk_repo = mock_deps["chunk_repo"]
        assert len(chunk_repo._chunks) == result["chunks_created"]

    @pytest.mark.asyncio
    async def test_pipeline_creates_shorts_in_firestore(self, mock_deps, seeded_pipeline):
        note_id, task_id = seeded_pipeline

        orchestrator = PipelineOrchestrator(**mock_deps)
        result = await orchestrator.process(_TEST_USER, note_id, task_id)

        short_repo = mock_deps["short_repo"]
        assert len(short_repo._shorts) == result["shorts_created"]

    @pytest.mark.asyncio
    async def test_pipeline_stores_embeddings_in_vector_store(self, mock_deps, seeded_pipeline):
        note_id, task_id = seeded_pipeline

        orchestrator = PipelineOrchestrator(**mock_deps)
        result = await orchestrator.process(_TEST_USER, note_id, task_id)

        vector_store = mock_deps["vector_store"]
        count = await vector_store.count(_TEST_USER)
        assert count == result["chunks_created"]

    @pytest.mark.asyncio
    async def test_pipeline_tracks_stage_progress(self, mock_deps, seeded_pipeline):
        note_id, task_id = seeded_pipeline

        orchestrator = PipelineOrchestrator(**mock_deps)
        await orchestrator.process(_TEST_USER, note_id, task_id)

        task = await mock_deps["processing_task_repo"].get(task_id)
        stages = task.stages
        assert "extraction" in stages
        assert "chunking" in stages
        assert "deduplication" in stages
        assert "embedding" in stages
        assert "short_generation" in stages
        assert "storage" in stages


class TestPipelineErrors:
    @pytest.mark.asyncio
    async def test_nonexistent_note_fails(self, mock_deps):
        task_repo = mock_deps["processing_task_repo"]
        task = ProcessingTaskDocument(
            user_id=_TEST_USER,
            note_id="nonexistent",
            status=ProcessingStatus.PENDING,
        )
        task_id = await task_repo.create(task)

        orchestrator = PipelineOrchestrator(**mock_deps)

        with pytest.raises(Exception):
            await orchestrator.process(_TEST_USER, "nonexistent", task_id)

        task = await task_repo.get(task_id)
        assert task.status == ProcessingStatus.FAILED


class TestAntiDensity:
    """CP-17: Anti-density controls."""

    @pytest.mark.asyncio
    async def test_respects_max_shorts_per_source(self, mock_deps, seeded_pipeline):
        note_id, task_id = seeded_pipeline

        # Set max to 1
        mock_deps["settings"] = Settings(
            chunk_target_words=50,
            chunk_overlap_words=10,
            anti_density_max_per_source=1,
        )

        orchestrator = PipelineOrchestrator(**mock_deps)
        result = await orchestrator.process(_TEST_USER, note_id, task_id)

        # Should create at most 1 short
        assert result["shorts_created"] <= 1
