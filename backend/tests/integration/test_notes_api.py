"""Integration tests for Notes CRUD API — lightweight mock pattern."""

from __future__ import annotations

import uuid
from unittest.mock import MagicMock, patch

import pytest
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

from app.api.v1.notes import router
from app.exceptions import NotFoundError
from app.models.note import NoteDocument
from app.models.processing_task import ProcessingTaskDocument

_TEST_USER = "test-user-001"

# Patch targets for lazy-imported Celery tasks
_PATCH_PROCESS_NOTE = "app.workers.pipeline_tasks.process_note"
_PATCH_CASCADE_DELETE = "app.workers.lifecycle_tasks.cascade_note_delete"
_PATCH_CASCADE_UPDATE = "app.workers.lifecycle_tasks.cascade_note_update"


class MockNoteRepository:
    """In-memory note repository for integration tests."""

    def __init__(self):
        self._store: dict[str, NoteDocument] = {}

    async def create(self, user_id, data):
        doc_id = str(uuid.uuid4())[:8]
        data.id = doc_id
        self._store[doc_id] = data
        return doc_id

    async def get(self, user_id, doc_id):
        return self._store.get(doc_id)

    async def list(self, user_id, limit=50, cursor=None, order_by="createdAt", direction="DESCENDING"):
        items = list(self._store.values())[:limit]
        return items, None

    async def update(self, user_id, doc_id, data):
        if doc_id in self._store:
            note = self._store[doc_id]
            for key, value in data.items():
                if hasattr(note, key):
                    setattr(note, key, value)
                elif key == "processingTaskId":
                    note.processing_task_id = value

    async def delete(self, user_id, doc_id):
        self._store.pop(doc_id, None)


class MockProcessingTaskRepository:
    """In-memory processing task repository."""

    def __init__(self):
        self._store: dict[str, ProcessingTaskDocument] = {}

    async def create(self, data):
        doc_id = str(uuid.uuid4())[:8]
        self._store[doc_id] = data
        return doc_id

    async def get_by_note(self, user_id, note_id):
        for task in self._store.values():
            if task.note_id == note_id and task.user_id == user_id:
                return task
        return None


def _make_test_app(note_repo: MockNoteRepository, task_repo: MockProcessingTaskRepository) -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.dependencies import get_note_repository, get_processing_task_repository

    app = FastAPI()

    # Register exception handler for NotFoundError (normally done in create_app)
    @app.exception_handler(NotFoundError)
    async def not_found_handler(_request: Request, exc: NotFoundError) -> JSONResponse:
        return JSONResponse(
            status_code=404,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    app.include_router(router, prefix="/api/v1")

    # Use shared instances (not factories) so state persists across requests
    app.dependency_overrides[verify_firebase_token] = lambda: _TEST_USER
    app.dependency_overrides[get_note_repository] = lambda: note_repo
    app.dependency_overrides[get_processing_task_repository] = lambda: task_repo

    return app


@pytest.fixture
def client():
    note_repo = MockNoteRepository()
    task_repo = MockProcessingTaskRepository()
    return TestClient(_make_test_app(note_repo, task_repo))


class TestCreateNote:
    @patch(_PATCH_PROCESS_NOTE)
    def test_create_text_note(self, mock_task, client):
        mock_task.delay = MagicMock()
        response = client.post(
            "/api/v1/notes/",
            data={"content": "My first note about machine learning."},
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["id"]
        assert data["type"] == "text"
        assert data["processingTaskId"]
        assert data["processed"] is False

    @patch(_PATCH_PROCESS_NOTE)
    def test_create_note_with_title(self, mock_task, client):
        mock_task.delay = MagicMock()
        response = client.post(
            "/api/v1/notes/",
            data={
                "content": "Content here.",
                "title": "My ML Note",
            },
        )
        assert response.status_code == 200
        assert response.json()["data"]["title"] == "My ML Note"

    @patch(_PATCH_PROCESS_NOTE)
    def test_create_note_with_topics(self, mock_task, client):
        mock_task.delay = MagicMock()
        response = client.post(
            "/api/v1/notes/",
            data={
                "content": "Content here.",
                "topics": "ml,ai,deep-learning",
            },
        )
        assert response.status_code == 200

    @patch(_PATCH_PROCESS_NOTE)
    def test_create_note_requires_content(self, mock_task, client):
        response = client.post(
            "/api/v1/notes/",
            data={},
        )
        assert response.status_code == 422


class TestListNotes:
    def test_list_empty(self, client):
        response = client.get("/api/v1/notes/")
        assert response.status_code == 200
        body = response.json()
        assert "data" in body
        assert isinstance(body["data"], list)
        assert "meta" in body

    def test_list_with_pagination_params(self, client):
        response = client.get("/api/v1/notes/?limit=10")
        assert response.status_code == 200

    @patch(_PATCH_PROCESS_NOTE)
    def test_list_after_create(self, mock_task, client):
        mock_task.delay = MagicMock()
        client.post(
            "/api/v1/notes/",
            data={"content": "Test note content."},
        )
        response = client.get("/api/v1/notes/")
        assert response.status_code == 200
        assert len(response.json()["data"]) >= 1


class TestGetNote:
    def test_get_nonexistent_note(self, client):
        response = client.get("/api/v1/notes/nonexistent-id")
        assert response.status_code == 404

    @patch(_PATCH_PROCESS_NOTE)
    def test_get_existing_note(self, mock_task, client):
        mock_task.delay = MagicMock()
        create_resp = client.post(
            "/api/v1/notes/",
            data={"content": "Note to retrieve."},
        )
        note_id = create_resp.json()["data"]["id"]

        response = client.get(f"/api/v1/notes/{note_id}")
        assert response.status_code == 200
        assert response.json()["data"]["id"] == note_id


class TestUpdateNote:
    def test_update_nonexistent_note(self, client):
        response = client.put(
            "/api/v1/notes/nonexistent-id",
            json={"title": "New Title"},
        )
        assert response.status_code == 404

    @patch(_PATCH_PROCESS_NOTE)
    def test_update_title(self, mock_task, client):
        mock_task.delay = MagicMock()
        create_resp = client.post(
            "/api/v1/notes/",
            data={"content": "Original content."},
        )
        note_id = create_resp.json()["data"]["id"]

        response = client.put(
            f"/api/v1/notes/{note_id}",
            json={"title": "Updated Title"},
        )
        assert response.status_code == 200


class TestDeleteNote:
    def test_delete_nonexistent_note(self, client):
        response = client.delete("/api/v1/notes/nonexistent-id")
        assert response.status_code == 404

    @patch(_PATCH_CASCADE_DELETE)
    @patch(_PATCH_PROCESS_NOTE)
    def test_delete_existing_note(self, mock_process, mock_cascade, client):
        mock_process.delay = MagicMock()
        mock_cascade.delay = MagicMock()
        create_resp = client.post(
            "/api/v1/notes/",
            data={"content": "Note to delete."},
        )
        note_id = create_resp.json()["data"]["id"]

        response = client.delete(f"/api/v1/notes/{note_id}")
        assert response.status_code == 200
        assert response.json()["data"]["deleted"] is True

        get_resp = client.get(f"/api/v1/notes/{note_id}")
        assert get_resp.status_code == 404


class TestProcessingStatus:
    def test_status_no_task(self, client):
        response = client.get("/api/v1/notes/some-id/status")
        assert response.status_code == 200
        assert response.json()["data"]["status"] == "no_task"
