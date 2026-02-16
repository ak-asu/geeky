"""Unit tests for ProfileService."""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.exceptions import UserNotFoundError
from app.models.user import UserProfileUpdate
from app.services.profile.profile_service import ProfileService


@dataclass
class _MockUser:
    id: str = "user1"
    name: str = "Test User"
    email: str = "test@test.com"
    streak: MagicMock = field(default_factory=lambda: MagicMock(current=3, longest=7))

    def model_dump(self, **kwargs):
        return {"id": self.id, "name": self.name, "email": self.email}


@dataclass
class _MockNote:
    id: str = "n1"

    def model_dump(self, **kwargs):
        return {"id": self.id}


@dataclass
class _MockShort:
    id: str = "s1"

    def model_dump(self, **kwargs):
        return {"id": self.id}


def _make_repos(user=None, notes=0, shorts=0, concepts=0, reviews=0):
    user_repo = AsyncMock()
    user_repo.get = AsyncMock(return_value=user or _MockUser())
    user_repo.update = AsyncMock()
    user_repo.delete = AsyncMock()

    note_repo = AsyncMock()
    note_repo.count = AsyncMock(return_value=notes)
    note_repo.query = AsyncMock(return_value=[_MockNote(f"n{i}") for i in range(notes)])
    note_repo.delete = AsyncMock()

    short_repo = AsyncMock()
    short_repo.count = AsyncMock(return_value=shorts)
    short_repo.query = AsyncMock(return_value=[_MockShort(f"s{i}") for i in range(shorts)])
    short_repo.delete = AsyncMock()

    concept_repo = AsyncMock()
    concept_repo.count = AsyncMock(return_value=concepts)
    concept_repo.query = AsyncMock(return_value=[])
    concept_repo.delete = AsyncMock()

    review_state_repo = AsyncMock()
    review_state_repo.count = AsyncMock(return_value=reviews)
    review_state_repo.query = AsyncMock(return_value=[])
    review_state_repo.delete = AsyncMock()

    interaction_repo = AsyncMock()
    interaction_repo.query = AsyncMock(return_value=[])
    interaction_repo.delete = AsyncMock()

    bookmark_repo = AsyncMock()
    bookmark_repo.query = AsyncMock(return_value=[])
    bookmark_repo.delete = AsyncMock()

    chunk_repo = AsyncMock()
    chunk_repo.query = AsyncMock(return_value=[])
    chunk_repo.delete = AsyncMock()

    quiz_attempt_repo = AsyncMock()
    quiz_attempt_repo.query = AsyncMock(return_value=[])
    quiz_attempt_repo.delete = AsyncMock()

    return {
        "user_repo": user_repo,
        "note_repo": note_repo,
        "short_repo": short_repo,
        "concept_repo": concept_repo,
        "review_state_repo": review_state_repo,
        "interaction_repo": interaction_repo,
        "bookmark_repo": bookmark_repo,
        "chunk_repo": chunk_repo,
        "quiz_attempt_repo": quiz_attempt_repo,
    }


class TestGetProfile:
    @pytest.mark.asyncio
    async def test_returns_user_document(self):
        repos = _make_repos()
        service = ProfileService(**repos)
        profile = await service.get_profile("user1")
        assert profile.name == "Test User"

    @pytest.mark.asyncio
    async def test_not_found_raises(self):
        repos = _make_repos()
        repos["user_repo"].get = AsyncMock(return_value=None)
        service = ProfileService(**repos)

        with pytest.raises(UserNotFoundError):
            await service.get_profile("nonexistent")


class TestUpdateProfile:
    @pytest.mark.asyncio
    async def test_updates_fields(self):
        repos = _make_repos()
        service = ProfileService(**repos)

        update = UserProfileUpdate(name="New Name")
        result = await service.update_profile("user1", update)

        repos["user_repo"].update.assert_called_once()
        assert result.name == "Test User"  # Mock returns same object

    @pytest.mark.asyncio
    async def test_not_found_raises(self):
        repos = _make_repos()
        repos["user_repo"].get = AsyncMock(return_value=None)
        service = ProfileService(**repos)

        with pytest.raises(UserNotFoundError):
            await service.update_profile("nonexistent", UserProfileUpdate(name="x"))


class TestGetStats:
    @pytest.mark.asyncio
    async def test_returns_counts(self):
        repos = _make_repos(notes=5, shorts=20, concepts=10, reviews=15)
        service = ProfileService(**repos)
        stats = await service.get_stats("user1")

        assert stats["totalNotes"] == 5
        assert stats["totalShorts"] == 20
        assert stats["totalConcepts"] == 10
        assert stats["totalReviewStates"] == 15
        assert stats["streak"]["current"] == 3


class TestExportData:
    @pytest.mark.asyncio
    async def test_exports_all_collections(self):
        repos = _make_repos(notes=2, shorts=3)
        service = ProfileService(**repos)
        export = await service.export_data("user1")

        assert "profile" in export
        assert "notes" in export
        assert "shorts" in export
        assert "exportedAt" in export

    @pytest.mark.asyncio
    async def test_not_found_raises(self):
        repos = _make_repos()
        repos["user_repo"].get = AsyncMock(return_value=None)
        service = ProfileService(**repos)

        with pytest.raises(UserNotFoundError):
            await service.export_data("nonexistent")


class TestDeleteAccount:
    @pytest.mark.asyncio
    async def test_deletes_all_subcollections(self):
        repos = _make_repos(notes=2, shorts=3)
        service = ProfileService(**repos)
        await service.delete_account("user1")

        repos["user_repo"].delete.assert_called_once()
        repos["note_repo"].delete.assert_called()
        repos["short_repo"].delete.assert_called()

    @pytest.mark.asyncio
    async def test_not_found_raises(self):
        repos = _make_repos()
        repos["user_repo"].get = AsyncMock(return_value=None)
        service = ProfileService(**repos)

        with pytest.raises(UserNotFoundError):
            await service.delete_account("nonexistent")
