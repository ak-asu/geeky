"""Unit tests for FirestoreFeatureFlags."""
from __future__ import annotations

import time
from unittest.mock import MagicMock, patch

import pytest

from app.services.feature_flags.firestore_flags import FirestoreFeatureFlags


def _make_doc_snapshot(data: dict | None, exists: bool = True):
    """Create a mock Firestore DocumentSnapshot."""
    snap = MagicMock()
    snap.exists = exists
    snap.to_dict = MagicMock(return_value=data)
    return snap


def _make_db(flags: dict | None = None, exists: bool = True):
    """Create a mock sync Firestore client that returns the given flags."""
    snap = _make_doc_snapshot({"flags": flags} if flags is not None else None, exists=exists)
    doc_ref = MagicMock()
    doc_ref.get = MagicMock(return_value=snap)
    db = MagicMock()
    db.collection.return_value.document.return_value = doc_ref
    return db, doc_ref


class TestIsEnabled:
    @pytest.mark.asyncio
    async def test_returns_true_when_flag_enabled(self):
        db, _ = _make_db(flags={"rag_enabled": True})
        flags = FirestoreFeatureFlags(db=db, ttl_seconds=60)

        with _patch_to_thread(db):
            result = await flags.is_enabled("rag_enabled")
        assert result is True

    @pytest.mark.asyncio
    async def test_returns_default_when_flag_missing(self):
        db, _ = _make_db(flags={"other_flag": True})
        flags = FirestoreFeatureFlags(db=db, ttl_seconds=60)

        with _patch_to_thread(db):
            result = await flags.is_enabled("missing_flag", default=False)
        assert result is False

    @pytest.mark.asyncio
    async def test_returns_default_when_firestore_fails(self):
        db = MagicMock()
        doc_ref = MagicMock()
        doc_ref.get = MagicMock(side_effect=Exception("connection failed"))
        db.collection.return_value.document.return_value = doc_ref

        flags = FirestoreFeatureFlags(db=db, ttl_seconds=60)
        import asyncio
        with patch.object(asyncio, "to_thread", side_effect=lambda fn, *a: fn()):
            result = await flags.is_enabled("rag_enabled", default=True)
        # Fails silently, returns default
        assert result is True

    @pytest.mark.asyncio
    async def test_ttl_cache_prevents_second_firestore_call(self):
        db, doc_ref = _make_db(flags={"rag_enabled": True})
        flags = FirestoreFeatureFlags(db=db, ttl_seconds=60)

        import asyncio
        with patch.object(asyncio, "to_thread", side_effect=lambda fn, *a: fn()):
            await flags.is_enabled("rag_enabled")
            await flags.is_enabled("rag_enabled")

        # Firestore called only once due to TTL cache
        assert doc_ref.get.call_count == 1

    @pytest.mark.asyncio
    async def test_cache_refreshes_after_ttl(self):
        db, doc_ref = _make_db(flags={"rag_enabled": True})
        flags = FirestoreFeatureFlags(db=db, ttl_seconds=0.01)  # very short TTL

        import asyncio
        with patch.object(asyncio, "to_thread", side_effect=lambda fn, *a: fn()):
            await flags.is_enabled("rag_enabled")
            time.sleep(0.02)  # expire TTL
            await flags.is_enabled("rag_enabled")

        assert doc_ref.get.call_count == 2


def _patch_to_thread(db):
    """Context manager that makes asyncio.to_thread call the function synchronously."""
    import asyncio
    from unittest.mock import patch

    def sync_to_thread(fn, *args):
        return fn(*args) if args else fn()

    return patch.object(asyncio, "to_thread", side_effect=sync_to_thread)


class TestGetValue:
    @pytest.mark.asyncio
    async def test_returns_raw_value(self):
        db, _ = _make_db(flags={"max_notes_free": 50})
        flags = FirestoreFeatureFlags(db=db, ttl_seconds=60)

        with _patch_to_thread(db):
            result = await flags.get_value("max_notes_free", default=100)
        assert result == 50

    @pytest.mark.asyncio
    async def test_returns_default_when_missing(self):
        db, _ = _make_db(flags={})
        flags = FirestoreFeatureFlags(db=db, ttl_seconds=60)

        with _patch_to_thread(db):
            result = await flags.get_value("nonexistent", default=42)
        assert result == 42
