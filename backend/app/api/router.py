"""Root API router aggregating all v1 feature routers."""

from __future__ import annotations

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

api_router = APIRouter()

# --- Health Check (no auth) ---


@api_router.get("/health", tags=["health"])
async def health_check() -> dict:
    """Basic health check endpoint."""
    return {"status": "healthy"}


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
