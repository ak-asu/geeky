"""Unit tests for BookmarkService."""

from __future__ import annotations

from dataclasses import dataclass
from unittest.mock import AsyncMock

import pytest

from app.exceptions import ShortNotFoundError
from app.services.bookmark.bookmark_service import BookmarkService


@dataclass
class _MockShort:
    id: str = "s1"
    title: str = "Test Short"
    summary: str = "Summary"
    topics: list = None
    difficulty: float = 0.5

    def __post_init__(self):
        if self.topics is None:
            self.topics = ["ml"]


@dataclass
class _MockBookmark:
    id: str = "b1"
    short_id: str = "s1"
    created_at: None = None


def _make_service(short_exists=True, bookmark_exists=False):
    bookmark_repo = AsyncMock()
    short_repo = AsyncMock()

    short_repo.get = AsyncMock(
        return_value=_MockShort() if short_exists else None
    )

    bookmark_repo.get_by_short = AsyncMock(
        return_value=_MockBookmark() if bookmark_exists else None
    )
    bookmark_repo.create = AsyncMock(return_value="new-bookmark-id")
    bookmark_repo.delete_by_short = AsyncMock(return_value=True)
    bookmark_repo.list = AsyncMock(
        return_value=([_MockBookmark()], None)
    )

    service = BookmarkService(
        bookmark_repo=bookmark_repo,
        short_repo=short_repo,
    )
    return service, bookmark_repo, short_repo


class TestCreateBookmark:
    @pytest.mark.asyncio
    async def test_creates_new_bookmark(self):
        service, bookmark_repo, _ = _make_service()
        result = await service.create_bookmark("user1", "s1")

        assert result["id"] == "new-bookmark-id"
        assert result["shortId"] == "s1"
        assert result["alreadyBookmarked"] is False
        bookmark_repo.create.assert_called_once()

    @pytest.mark.asyncio
    async def test_returns_existing_when_already_bookmarked(self):
        service, bookmark_repo, _ = _make_service(bookmark_exists=True)
        result = await service.create_bookmark("user1", "s1")

        assert result["alreadyBookmarked"] is True
        assert result["id"] == "b1"
        bookmark_repo.create.assert_not_called()

    @pytest.mark.asyncio
    async def test_raises_when_short_not_found(self):
        service, _, _ = _make_service(short_exists=False)

        with pytest.raises(ShortNotFoundError):
            await service.create_bookmark("user1", "nonexistent")


class TestRemoveBookmark:
    @pytest.mark.asyncio
    async def test_removes_bookmark(self):
        service, bookmark_repo, _ = _make_service()
        result = await service.remove_bookmark("user1", "s1")

        assert result is True
        bookmark_repo.delete_by_short.assert_called_once_with("user1", "s1")

    @pytest.mark.asyncio
    async def test_returns_false_when_not_found(self):
        service, bookmark_repo, _ = _make_service()
        bookmark_repo.delete_by_short = AsyncMock(return_value=False)
        result = await service.remove_bookmark("user1", "nonexistent")

        assert result is False


class TestListBookmarks:
    @pytest.mark.asyncio
    async def test_returns_bookmarks_with_short_metadata(self):
        service, _, _ = _make_service()
        items, cursor = await service.list_bookmarks("user1")

        assert len(items) == 1
        assert items[0]["shortId"] == "s1"
        assert items[0]["short"]["title"] == "Test Short"
        assert cursor is None

    @pytest.mark.asyncio
    async def test_handles_missing_short(self):
        service, _, short_repo = _make_service()
        short_repo.get = AsyncMock(return_value=None)
        items, _ = await service.list_bookmarks("user1")

        assert len(items) == 1
        assert "short" not in items[0]
