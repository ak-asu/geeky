"""Shared test fixtures and configuration.

Provides mock implementations of all Protocol interfaces,
a configured TestClient, and common test data factories.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def app():
    """Create a test FastAPI app."""
    from app.main import create_app

    return create_app()


@pytest.fixture
def client(app):
    """Create a test HTTP client."""
    return TestClient(app)


@pytest.fixture
def auth_headers():
    """Mock authenticated request headers.

    In integration tests, the auth middleware should be overridden
    to skip actual Firebase token verification.
    """
    return {"Authorization": "Bearer test-token-123"}


@pytest.fixture
def test_user_id():
    """Standard test user ID."""
    return "test-user-001"


@pytest.fixture
def mock_firestore(mocker):
    """Mock Firestore client."""
    # TODO: Implement mock Firestore in Phase 2
    return mocker.MagicMock()
