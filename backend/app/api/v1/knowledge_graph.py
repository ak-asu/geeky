from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/kg", tags=["knowledge-graph"])


@router.get("/concepts")
async def list_concepts(user_id: CurrentUserId) -> dict:
    """List all concepts in the user's knowledge graph."""
    return {"message": "Not implemented yet"}


@router.get("/relationships")
async def list_relationships(user_id: CurrentUserId) -> dict:
    """List all relationships between concepts."""
    return {"message": "Not implemented yet"}


@router.get("/graph")
async def get_full_graph(user_id: CurrentUserId) -> dict:
    """Get the full knowledge graph data (concepts + relationships)."""
    return {"message": "Not implemented yet"}


@router.get("/concepts/{concept_id}/navigate")
async def get_navigation_options(
    concept_id: str, user_id: CurrentUserId
) -> dict:
    """Get navigation options (neighbors, related concepts) from a concept."""
    return {"message": "Not implemented yet"}


@router.get("/concepts/{concept_id}/path")
async def get_path_to_target(
    concept_id: str,
    target_id: str,
    user_id: CurrentUserId,
) -> dict:
    """Find the shortest path from a concept to a target concept."""
    return {"message": "Not implemented yet"}


@router.post("/rebuild")
async def rebuild_graph(user_id: CurrentUserId) -> dict:
    """Trigger a full rebuild of the user's knowledge graph."""
    return {"message": "Not implemented yet"}
