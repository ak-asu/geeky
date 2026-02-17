"""Integration tests for Modules API routes."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.modules import router
from app.models.common import ModuleType
from app.models.module import ModuleDocument


class MockModuleService:
    async def create_module(self, user_id, data):
        return ModuleDocument(
            id="m1",
            name=data.name,
            description=data.description,
            topics=data.topics,
            short_ids=data.short_ids,
            type=data.type,
            total_shorts=len(data.short_ids),
        )

    async def list_modules(self, user_id, limit=50, cursor=None):
        return [
            ModuleDocument(id="m1", name="Module 1", total_shorts=3),
        ], None

    async def get_module(self, user_id, module_id):
        return ModuleDocument(id=module_id, name="Module 1", total_shorts=3)

    async def update_module(self, user_id, module_id, data):
        return ModuleDocument(
            id=module_id,
            name=data.name or "Module 1",
            total_shorts=3,
        )

    async def delete_module(self, user_id, module_id):
        pass


def _make_test_app() -> FastAPI:
    from app.api.middleware.auth import verify_firebase_token
    from app.dependencies import get_module_service

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    app.dependency_overrides[verify_firebase_token] = lambda: "test-user-001"
    app.dependency_overrides[get_module_service] = lambda: MockModuleService()

    return app


@pytest.fixture
def client():
    return TestClient(_make_test_app())


class TestCreateModule:
    def test_creates_module(self, client):
        resp = client.post("/api/v1/modules/", json={
            "name": "ML Basics",
            "description": "Intro to ML",
            "topics": ["ml"],
            "shortIds": ["s1", "s2"],
        })
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["name"] == "ML Basics"
        assert data["totalShorts"] == 2


class TestListModules:
    def test_lists_modules(self, client):
        resp = client.get("/api/v1/modules/")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 1
        assert data[0]["name"] == "Module 1"

    def test_pagination_meta(self, client):
        resp = client.get("/api/v1/modules/?limit=10")
        assert resp.status_code == 200
        meta = resp.json()["meta"]
        assert meta["hasMore"] is False


class TestGetModule:
    def test_gets_module(self, client):
        resp = client.get("/api/v1/modules/m1")
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["id"] == "m1"


class TestUpdateModule:
    def test_updates_module(self, client):
        resp = client.patch("/api/v1/modules/m1", json={
            "name": "Updated Module",
        })
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["name"] == "Updated Module"


class TestDeleteModule:
    def test_deletes_module(self, client):
        resp = client.delete("/api/v1/modules/m1")
        assert resp.status_code == 200
        assert resp.json()["data"]["deleted"] is True
