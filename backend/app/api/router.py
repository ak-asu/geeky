"""Root API router aggregating all v1 feature routers."""

from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter

from app.api.v1 import (
    analytics,
    bookmarks,
    knowledge_graph,
    modules,
    notes,
    notifications,
    quiz,
    rag,
    recommendations,
    search,
    shorts,
    sources,
    subscription,
    sync,
    users,
)
from app.config import get_settings

logger = logging.getLogger(__name__)

api_router = APIRouter()

# --- Health Check (no auth) ---


async def _probe_firebase(timeout: float) -> dict:
    """Probe Firebase by listing a top-level collection."""
    try:
        from app.dependencies import get_firestore_db  # noqa: PLC0415

        async def _check():
            db = get_firestore_db()
            # Lightweight: read a known doc (app_config/global)
            doc_ref = db.collection("app_config").document("global")
            await asyncio.to_thread(doc_ref.get)

        await asyncio.wait_for(_check(), timeout=timeout)
        return {"status": "ok"}
    except asyncio.TimeoutError:
        logger.warning("Firebase health probe timed out")
        return {"status": "timeout"}
    except Exception as exc:
        logger.warning("Firebase health probe failed: %s", exc)
        return {"status": "error", "detail": str(exc)[:100]}


async def _probe_chromadb(timeout: float) -> dict:
    """Probe ChromaDB by calling heartbeat."""
    try:
        from app.dependencies import get_vector_store  # noqa: PLC0415

        async def _check():
            store = get_vector_store()
            # ChromaDB client has a heartbeat method
            await asyncio.to_thread(store._client.heartbeat)

        await asyncio.wait_for(_check(), timeout=timeout)
        return {"status": "ok"}
    except asyncio.TimeoutError:
        logger.warning("ChromaDB health probe timed out")
        return {"status": "timeout"}
    except Exception as exc:
        logger.warning("ChromaDB health probe failed: %s", exc)
        return {"status": "error", "detail": str(exc)[:100]}


async def _probe_redis(timeout: float) -> dict:
    """Probe Redis with a PING command."""
    try:
        import redis.asyncio as aioredis  # noqa: PLC0415

        settings = get_settings()

        async def _check():
            r = aioredis.from_url(settings.redis_url, decode_responses=True)
            try:
                await r.ping()
            finally:
                await r.aclose()

        await asyncio.wait_for(_check(), timeout=timeout)
        return {"status": "ok"}
    except asyncio.TimeoutError:
        logger.warning("Redis health probe timed out")
        return {"status": "timeout"}
    except ImportError:
        return {"status": "skipped", "detail": "redis not installed"}
    except Exception as exc:
        logger.warning("Redis health probe failed: %s", exc)
        return {"status": "error", "detail": str(exc)[:100]}


@api_router.get("/health", tags=["health"])
async def health_check() -> dict:
    """Dependency-aware health check.

    Returns "ok" only if all dependencies are reachable.
    Returns "degraded" if any dependency is unhealthy (stays 200 — Cloud Run keeps routing).
    """
    settings = get_settings()
    timeout = settings.health_probe_timeout_seconds

    firebase_result, chromadb_result, redis_result = await asyncio.gather(
        _probe_firebase(timeout),
        _probe_chromadb(timeout),
        _probe_redis(timeout),
        return_exceptions=False,
    )

    checks = {
        "firebase": firebase_result,
        "chromadb": chromadb_result,
        "redis": redis_result,
    }

    all_healthy = all(c.get("status") in ("ok", "skipped") for c in checks.values())

    return {
        "status": "ok" if all_healthy else "degraded",
        "version": settings.app_version,
        "environment": settings.environment,
        "checks": checks,
    }


# --- V1 Routes ---
v1_router = APIRouter(prefix="/api/v1", tags=["v1"])

v1_router.include_router(notes.router)
v1_router.include_router(shorts.router)
v1_router.include_router(modules.router)
v1_router.include_router(knowledge_graph.router)
v1_router.include_router(rag.router)
v1_router.include_router(quiz.router)
v1_router.include_router(search.router)
v1_router.include_router(analytics.router)
v1_router.include_router(bookmarks.router)
v1_router.include_router(sources.router)
v1_router.include_router(notifications.router)
v1_router.include_router(users.router)
v1_router.include_router(sync.router)
v1_router.include_router(recommendations.router)
v1_router.include_router(subscription.router)

api_router.include_router(v1_router)
