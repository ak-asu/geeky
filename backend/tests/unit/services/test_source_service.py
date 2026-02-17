"""Unit tests for SourceService."""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import AsyncMock, patch

import pytest

from app.exceptions import SourceNotFoundError
from app.models.common import SourceStatus, SourceType
from app.models.source import SourceCreate
from app.services.source.source_service import SourceService


@dataclass
class _MockSource:
    id: str = "src1"
    name: str = "Test Source"
    url: str = "https://example.com/feed"
    type: SourceType = SourceType.RSS
    status: SourceStatus = SourceStatus.ACTIVE
    health_score: float = 1.0


def _make_service(source_exists=True):
    source_repo = AsyncMock()
    source_repo.get = AsyncMock(
        return_value=_MockSource() if source_exists else None
    )
    source_repo.create = AsyncMock(return_value="new-source-id")
    source_repo.query = AsyncMock(return_value=[_MockSource()])
    source_repo.delete = AsyncMock()
    source_repo.update = AsyncMock()

    service = SourceService(source_repo=source_repo)
    return service, source_repo


class TestAddSource:
    @pytest.mark.asyncio
    async def test_creates_source(self):
        service, source_repo = _make_service()
        data = SourceCreate(
            type=SourceType.RSS,
            name="Test Feed",
            url="https://example.com/rss",
        )
        result = await service.add_source("user1", data)

        assert result.id == "new-source-id"
        assert result.name == "Test Feed"
        source_repo.create.assert_called_once()


class TestListSources:
    @pytest.mark.asyncio
    async def test_returns_sources(self):
        service, _ = _make_service()
        sources = await service.list_sources("user1")

        assert len(sources) == 1
        assert sources[0].name == "Test Source"


class TestRemoveSource:
    @pytest.mark.asyncio
    async def test_removes_source(self):
        service, source_repo = _make_service()
        await service.remove_source("user1", "src1")
        source_repo.delete.assert_called_once_with("user1", "src1")

    @pytest.mark.asyncio
    async def test_raises_when_not_found(self):
        service, _ = _make_service(source_exists=False)

        with pytest.raises(SourceNotFoundError):
            await service.remove_source("user1", "nonexistent")


class TestCheckHealth:
    @pytest.mark.asyncio
    async def test_healthy_source(self):
        service, source_repo = _make_service()

        mock_response = AsyncMock()
        mock_response.status_code = 200

        with patch("app.services.source.source_service.httpx.AsyncClient") as mock_client:
            instance = AsyncMock()
            instance.head = AsyncMock(return_value=mock_response)
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.__aexit__ = AsyncMock(return_value=None)
            mock_client.return_value = instance

            result = await service.check_health("user1", "src1")

        assert result["healthScore"] == 1.0
        assert result["status"] == "active"
        source_repo.update.assert_called_once()

    @pytest.mark.asyncio
    async def test_unhealthy_source(self):
        service, _ = _make_service()

        mock_response = AsyncMock()
        mock_response.status_code = 500

        with patch("app.services.source.source_service.httpx.AsyncClient") as mock_client:
            instance = AsyncMock()
            instance.head = AsyncMock(return_value=mock_response)
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.__aexit__ = AsyncMock(return_value=None)
            mock_client.return_value = instance

            result = await service.check_health("user1", "src1")

        assert result["healthScore"] == 0.0
        assert result["status"] == "error"

    @pytest.mark.asyncio
    async def test_raises_when_source_not_found(self):
        service, _ = _make_service(source_exists=False)

        with pytest.raises(SourceNotFoundError):
            await service.check_health("user1", "nonexistent")

    @pytest.mark.asyncio
    async def test_timeout_returns_error(self):
        import httpx

        service, _ = _make_service()

        with patch("app.services.source.source_service.httpx.AsyncClient") as mock_client:
            instance = AsyncMock()
            instance.head = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.__aexit__ = AsyncMock(return_value=None)
            mock_client.return_value = instance

            result = await service.check_health("user1", "src1")

        assert result["healthScore"] == 0.0
        assert result["error"] == "Request timed out"
