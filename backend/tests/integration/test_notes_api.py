"""Integration tests for Notes CRUD API — via TestClient with mock Firebase."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from tests.mocks.mock_firebase import MockFirestoreClient

_TEST_USER = "test-user-001"


@pytest.fixture
def mock_db():
    return MockFirestoreClient()


@pytest.fixture
def app(mock_db):
    """Create app with mocked dependencies."""
    from app.main import create_app

    app = create_app()

    # Override auth to always return test user
    from app.api.middleware.auth import verify_firebase_token

    async def _mock_auth():
        return _TEST_USER

    app.dependency_overrides[verify_firebase_token] = _mock_auth

    # Override Firestore
    from app.dependencies import get_firestore_db

    app.dependency_overrides[get_firestore_db] = lambda: mock_db

    yield app
    app.dependency_overrides.clear()


@pytest.fixture
def client(app):
    return TestClient(app)


@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}


class TestCreateNote:
    def test_create_text_note(self, client, auth_headers):
        response = client.post(
            "/api/v1/notes/",
            data={"content": "My first note about machine learning."},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["id"]
        assert data["type"] == "text"
        assert data["processingTaskId"]
        assert data["processed"] is False

    def test_create_note_with_title(self, client, auth_headers):
        response = client.post(
            "/api/v1/notes/",
            data={
                "content": "Content here.",
                "title": "My ML Note",
            },
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json()["data"]["title"] == "My ML Note"

    def test_create_note_with_topics(self, client, auth_headers):
        response = client.post(
            "/api/v1/notes/",
            data={
                "content": "Content here.",
                "topics": "ml,ai,deep-learning",
            },
            headers=auth_headers,
        )
        assert response.status_code == 200

    def test_create_note_requires_content(self, client, auth_headers):
        response = client.post(
            "/api/v1/notes/",
            data={},
            headers=auth_headers,
        )
        assert response.status_code == 422

    def test_create_note_requires_auth(self, client):
        response = client.post(
            "/api/v1/notes/",
            data={"content": "test"},
        )
        # Should fail with 401 or 403
        assert response.status_code in (401, 403)


class TestListNotes:
    def test_list_empty(self, client, auth_headers):
        response = client.get("/api/v1/notes/", headers=auth_headers)
        assert response.status_code == 200
        body = response.json()
        assert "data" in body
        assert isinstance(body["data"], list)
        assert "meta" in body

    def test_list_with_pagination_params(self, client, auth_headers):
        response = client.get(
            "/api/v1/notes/?limit=10",
            headers=auth_headers,
        )
        assert response.status_code == 200

    def test_list_after_create(self, client, auth_headers):
        # Create a note first
        client.post(
            "/api/v1/notes/",
            data={"content": "Test note content."},
            headers=auth_headers,
        )
        response = client.get("/api/v1/notes/", headers=auth_headers)
        assert response.status_code == 200
        # Should have at least one note
        assert len(response.json()["data"]) >= 1


class TestGetNote:
    def test_get_nonexistent_note(self, client, auth_headers):
        response = client.get(
            "/api/v1/notes/nonexistent-id",
            headers=auth_headers,
        )
        assert response.status_code == 404

    def test_get_existing_note(self, client, auth_headers):
        # Create first
        create_resp = client.post(
            "/api/v1/notes/",
            data={"content": "Note to retrieve."},
            headers=auth_headers,
        )
        note_id = create_resp.json()["data"]["id"]

        # Get it
        response = client.get(f"/api/v1/notes/{note_id}", headers=auth_headers)
        assert response.status_code == 200
        assert response.json()["data"]["id"] == note_id


class TestUpdateNote:
    def test_update_nonexistent_note(self, client, auth_headers):
        response = client.put(
            "/api/v1/notes/nonexistent-id",
            json={"title": "New Title"},
            headers=auth_headers,
        )
        assert response.status_code == 404

    def test_update_title(self, client, auth_headers):
        # Create
        create_resp = client.post(
            "/api/v1/notes/",
            data={"content": "Original content."},
            headers=auth_headers,
        )
        note_id = create_resp.json()["data"]["id"]

        # Update
        response = client.put(
            f"/api/v1/notes/{note_id}",
            json={"title": "Updated Title"},
            headers=auth_headers,
        )
        assert response.status_code == 200


class TestDeleteNote:
    def test_delete_nonexistent_note(self, client, auth_headers):
        response = client.delete(
            "/api/v1/notes/nonexistent-id",
            headers=auth_headers,
        )
        assert response.status_code == 404

    def test_delete_existing_note(self, client, auth_headers):
        # Create
        create_resp = client.post(
            "/api/v1/notes/",
            data={"content": "Note to delete."},
            headers=auth_headers,
        )
        note_id = create_resp.json()["data"]["id"]

        # Delete
        response = client.delete(
            f"/api/v1/notes/{note_id}",
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json()["data"]["deleted"] is True

        # Verify gone
        get_resp = client.get(f"/api/v1/notes/{note_id}", headers=auth_headers)
        assert get_resp.status_code == 404


class TestProcessingStatus:
    def test_status_no_task(self, client, auth_headers):
        response = client.get(
            "/api/v1/notes/some-id/status",
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json()["data"]["status"] == "no_task"
