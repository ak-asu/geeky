"""Unit tests for ModuleService."""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import AsyncMock

import pytest

from app.exceptions import ModuleNotFoundError
from app.models.common import ModuleType
from app.models.module import ModuleCreate, ModuleUpdate
from app.services.module.module_service import ModuleService


@dataclass
class _MockModule:
    id: str = "m1"
    name: str = "Test Module"
    description: str = "A test module"
    topics: list = field(default_factory=lambda: ["ml"])
    short_ids: list = field(default_factory=lambda: ["s1", "s2"])
    type: ModuleType = ModuleType.MANUAL
    total_shorts: int = 2
    is_free: bool = False

    def model_dump(self, **kwargs):
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "topics": self.topics,
            "shortIds": self.short_ids,
            "type": self.type.value,
            "totalShorts": self.total_shorts,
            "isFree": self.is_free,
        }


def _make_service(module_exists=True):
    module_repo = AsyncMock()
    short_repo = AsyncMock()

    module_repo.get = AsyncMock(
        return_value=_MockModule() if module_exists else None
    )
    module_repo.create = AsyncMock(return_value="new-module-id")
    module_repo.list = AsyncMock(return_value=([_MockModule()], None))
    module_repo.update = AsyncMock()
    module_repo.delete = AsyncMock()

    service = ModuleService(
        module_repo=module_repo,
        short_repo=short_repo,
    )
    return service, module_repo


class TestCreateModule:
    @pytest.mark.asyncio
    async def test_creates_module(self):
        service, module_repo = _make_service()
        data = ModuleCreate(
            name="New Module",
            description="Desc",
            topics=["python"],
            short_ids=["s1", "s2", "s3"],
        )
        result = await service.create_module("user1", data)

        assert result.id == "new-module-id"
        assert result.total_shorts == 3
        module_repo.create.assert_called_once()

    @pytest.mark.asyncio
    async def test_empty_shorts_creates_module(self):
        service, module_repo = _make_service()
        data = ModuleCreate(name="Empty Module")
        result = await service.create_module("user1", data)

        assert result.total_shorts == 0


class TestListModules:
    @pytest.mark.asyncio
    async def test_returns_paginated_list(self):
        service, _ = _make_service()
        modules, cursor = await service.list_modules("user1")

        assert len(modules) == 1
        assert modules[0].name == "Test Module"
        assert cursor is None


class TestGetModule:
    @pytest.mark.asyncio
    async def test_returns_module(self):
        service, _ = _make_service()
        module = await service.get_module("user1", "m1")

        assert module.name == "Test Module"

    @pytest.mark.asyncio
    async def test_raises_when_not_found(self):
        service, _ = _make_service(module_exists=False)

        with pytest.raises(ModuleNotFoundError):
            await service.get_module("user1", "nonexistent")


class TestUpdateModule:
    @pytest.mark.asyncio
    async def test_updates_fields(self):
        service, module_repo = _make_service()
        data = ModuleUpdate(name="Updated Name")
        await service.update_module("user1", "m1", data)

        module_repo.update.assert_called_once()

    @pytest.mark.asyncio
    async def test_recomputes_total_shorts(self):
        service, module_repo = _make_service()
        data = ModuleUpdate(short_ids=["s1", "s2", "s3", "s4"])
        await service.update_module("user1", "m1", data)

        call_args = module_repo.update.call_args
        update_data = call_args[0][2]
        assert update_data["totalShorts"] == 4

    @pytest.mark.asyncio
    async def test_raises_when_not_found(self):
        service, _ = _make_service(module_exists=False)

        with pytest.raises(ModuleNotFoundError):
            await service.update_module("user1", "nonexistent", ModuleUpdate(name="x"))


class TestDeleteModule:
    @pytest.mark.asyncio
    async def test_deletes_module(self):
        service, module_repo = _make_service()
        await service.delete_module("user1", "m1")
        module_repo.delete.assert_called_once_with("user1", "m1")

    @pytest.mark.asyncio
    async def test_raises_when_not_found(self):
        service, _ = _make_service(module_exists=False)

        with pytest.raises(ModuleNotFoundError):
            await service.delete_module("user1", "nonexistent")
