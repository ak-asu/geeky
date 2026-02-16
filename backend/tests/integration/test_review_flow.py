"""Integration tests for the review flow: due → respond → reschedule."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.config import Settings
from app.models.review_state import ReviewStateDocument
from app.models.short import ShortDocument
from app.services.learning.review_manager import ReviewManager
from app.services.quiz.scheduler.fsrs_scheduler import FSRSScheduler


class InMemoryReviewStateRepo:
    """In-memory review state repository for testing."""

    def __init__(self):
        self._store: dict[str, ReviewStateDocument] = {}

    async def get(self, user_id, doc_id):
        return self._store.get(doc_id)

    async def get_by_short(self, user_id, short_id):
        for doc in self._store.values():
            if doc.short_id == short_id:
                return doc
        return None

    async def get_due(self, user_id, limit=20):
        now = datetime.now(timezone.utc)
        due = [
            doc for doc in self._store.values()
            if doc.due_date and doc.due_date <= now and doc.state != "new"
        ]
        due.sort(key=lambda d: d.due_date)
        return due[:limit]

    async def get_new(self, user_id, limit=10):
        new = [doc for doc in self._store.values() if doc.state == "new"]
        return new[:limit]

    async def create(self, user_id, doc, doc_id=None):
        self._store[doc_id or doc.id] = doc
        return doc_id or doc.id

    async def update(self, user_id, doc_id, data):
        doc = self._store.get(doc_id)
        if doc:
            for k, v in data.items():
                # Handle camelCase aliases
                field_map = {
                    "dueDate": "due_date",
                    "lastReviewDate": "last_review_date",
                }
                attr = field_map.get(k, k)
                if hasattr(doc, attr):
                    if attr in ("due_date", "last_review_date") and isinstance(v, str):
                        setattr(doc, attr, datetime.fromisoformat(v))
                    else:
                        setattr(doc, attr, v)


class InMemoryShortRepo:
    def __init__(self):
        self._shorts = {
            "s-1": ShortDocument(id="s-1", title="Intro to Python", content="Python basics."),
            "s-2": ShortDocument(id="s-2", title="Data Types", content="Strings, ints, floats."),
            "s-3": ShortDocument(id="s-3", title="Functions", content="Defining functions."),
        }

    async def get(self, user_id, short_id):
        return self._shorts.get(short_id)


@pytest.fixture
def review_repo():
    return InMemoryReviewStateRepo()


@pytest.fixture
def settings():
    return Settings(
        fsrs_desired_retention=0.9,
        review_default_batch=20,
        review_max_batch=50,
    )


@pytest.fixture
def manager(review_repo, settings):
    return ReviewManager(
        scheduler=FSRSScheduler(desired_retention=settings.fsrs_desired_retention),
        review_state_repo=review_repo,
        short_repo=InMemoryShortRepo(),
        settings=settings,
    )


class TestEnsureReviewStates:

    @pytest.mark.asyncio
    async def test_creates_states_for_new_shorts(self, manager, review_repo):
        created = await manager.ensure_review_states("user-001", ["s-1", "s-2", "s-3"])
        assert created == 3

    @pytest.mark.asyncio
    async def test_skips_existing_states(self, manager, review_repo):
        await manager.ensure_review_states("user-001", ["s-1"])
        created = await manager.ensure_review_states("user-001", ["s-1", "s-2"])
        assert created == 1  # Only s-2 is new


class TestGetDueCards:

    @pytest.mark.asyncio
    async def test_returns_new_cards(self, manager, review_repo):
        await manager.ensure_review_states("user-001", ["s-1", "s-2"])
        session = await manager.get_due_cards("user-001")
        assert session.new_count == 2
        assert len(session.cards) == 2

    @pytest.mark.asyncio
    async def test_returns_due_cards(self, manager, review_repo):
        # Create a card that's already due
        now = datetime.now(timezone.utc)
        doc = ReviewStateDocument(
            id="rs-1",
            short_id="s-1",
            state="review",
            due_date=now - timedelta(hours=1),
            last_review_date=now - timedelta(days=3),
            stability=3.0,
            difficulty=5.0,
            reps=2,
        )
        await review_repo.create("user-001", doc, doc_id="rs-1")

        session = await manager.get_due_cards("user-001")
        assert session.review_count == 1

    @pytest.mark.asyncio
    async def test_respects_limit(self, manager, review_repo):
        await manager.ensure_review_states("user-001", ["s-1", "s-2", "s-3"])
        session = await manager.get_due_cards("user-001", limit=2)
        assert len(session.cards) == 2


class TestSubmitReview:

    @pytest.mark.asyncio
    async def test_review_updates_state(self, manager, review_repo):
        await manager.ensure_review_states("user-001", ["s-1"])

        # Find the created review state
        state = await review_repo.get_by_short("user-001", "s-1")
        assert state is not None

        response = await manager.submit_review("user-001", state.id, rating=3)
        assert response.new_state in ("learning", "review")
        assert response.next_due is not None
        assert response.stability > 0

    @pytest.mark.asyncio
    async def test_again_increases_lapses_for_review_card(self, manager, review_repo):
        now = datetime.now(timezone.utc)
        doc = ReviewStateDocument(
            id="rs-2",
            short_id="s-2",
            state="review",
            due_date=now - timedelta(hours=1),
            last_review_date=now - timedelta(days=5),
            stability=5.0,
            difficulty=5.0,
            reps=3,
            lapses=0,
        )
        await review_repo.create("user-001", doc, doc_id="rs-2")

        response = await manager.submit_review("user-001", "rs-2", rating=1)
        assert response.new_state == "relearning"

        # Verify persisted state
        updated = await review_repo.get("user-001", "rs-2")
        assert updated.lapses == 1

    @pytest.mark.asyncio
    async def test_not_found_raises(self, manager):
        from app.exceptions import ReviewStateNotFoundError
        with pytest.raises(ReviewStateNotFoundError):
            await manager.submit_review("user-001", "nonexistent", rating=3)


class TestFullReviewCycle:
    """End-to-end: create states → get due → review → get due again."""

    @pytest.mark.asyncio
    async def test_full_cycle(self, manager, review_repo):
        # 1. Create review states
        await manager.ensure_review_states("user-001", ["s-1"])

        # 2. Get due (should be new card)
        session1 = await manager.get_due_cards("user-001")
        assert len(session1.cards) == 1
        card = session1.cards[0]
        assert card["state"] == "new"

        # 3. Review with "Good"
        response = await manager.submit_review("user-001", card["reviewStateId"], rating=3)
        assert response.next_due is not None

        # 4. Get due again (card should now be scheduled for future)
        session2 = await manager.get_due_cards("user-001")
        # The card we just reviewed should NOT be in due anymore
        due_ids = {c["reviewStateId"] for c in session2.cards}
        assert card["reviewStateId"] not in due_ids
