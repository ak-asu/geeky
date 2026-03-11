"""Knowledge Graph API routes.

Provides endpoints for querying the user's knowledge graph, including
summary stats, node listing, learning paths, and prerequisite chains.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.middleware.auth import CurrentUserId
from app.dependencies import (
    get_concept_repository,
    get_graph_query_service,
    get_relationship_repository,
)

router = APIRouter(prefix="/kg", tags=["knowledge-graph"])


# --- Summary ---


@router.get("")
async def get_kg_summary(
    user_id: CurrentUserId,
    query_service=Depends(get_graph_query_service),
) -> dict:
    """Get user's KG summary (node/edge counts, top concepts)."""
    summary = await query_service.get_summary(user_id)
    return {
        "data": {
            "nodeCount": summary.node_count,
            "edgeCount": summary.edge_count,
            "topConcepts": summary.top_concepts,
            "communityCount": summary.community_count,
        }
    }


# --- Nodes ---


@router.get("/nodes")
async def list_nodes(
    user_id: CurrentUserId,
    limit: int = Query(default=50, ge=1, le=200),
    cursor: str | None = None,
    concept_repo=Depends(get_concept_repository),
) -> dict:
    """List/search KG nodes with pagination."""
    items, next_cursor = await concept_repo.list(user_id, limit=limit, cursor=cursor)
    return {
        "data": [item.model_dump(mode="json", by_alias=True) for item in items],
        "meta": {"cursor": next_cursor, "hasMore": next_cursor is not None},
    }


@router.get("/nodes/{concept_id}")
async def get_node(
    concept_id: str,
    user_id: CurrentUserId,
    concept_repo=Depends(get_concept_repository),
) -> dict:
    """Get a specific KG node."""
    concept = await concept_repo.get(user_id, concept_id)
    if concept is None:
        from app.exceptions import ConceptNotFoundError  # noqa: PLC0415
        raise ConceptNotFoundError(concept_id)
    return {"data": concept.model_dump(mode="json", by_alias=True)}


@router.get("/nodes/{concept_id}/related")
async def get_related_concepts(
    concept_id: str,
    user_id: CurrentUserId,
    limit: int = Query(default=10, ge=1, le=50),
    query_service=Depends(get_graph_query_service),
) -> dict:
    """Get concepts related to a given concept."""
    related = await query_service.get_related_concepts(user_id, concept_id, limit=limit)
    return {"data": related}


# --- Edges ---


@router.get("/edges")
async def list_edges(
    user_id: CurrentUserId,
    limit: int = Query(default=50, ge=1, le=200),
    cursor: str | None = None,
    relationship_repo=Depends(get_relationship_repository),
) -> dict:
    """List KG edges with pagination."""
    items, next_cursor = await relationship_repo.list(user_id, limit=limit, cursor=cursor)
    return {
        "data": [item.model_dump(mode="json", by_alias=True) for item in items],
        "meta": {"cursor": next_cursor, "hasMore": next_cursor is not None},
    }


# --- Learning Paths ---


@router.get("/path")
async def get_learning_path(
    user_id: CurrentUserId,
    source: str = Query(alias="from", description="Source concept ID"),
    target: str = Query(alias="to", description="Target concept ID"),
    query_service=Depends(get_graph_query_service),
) -> dict:
    """Find the learning path between two concepts (KG-04)."""
    path = await query_service.get_learning_path(user_id, source, target)
    return {
        "data": {
            "source": path.source,
            "target": path.target,
            "found": path.found,
            "path": path.path,
            "totalWeight": path.total_weight,
        }
    }


@router.get("/prerequisites/{concept_id}")
async def get_prerequisites(
    concept_id: str,
    user_id: CurrentUserId,
    max_depth: int = Query(default=5, ge=1, le=10),
    query_service=Depends(get_graph_query_service),
) -> dict:
    """Get prerequisite chain for a concept (KG-04)."""
    chain = await query_service.get_prerequisites(user_id, concept_id, max_depth=max_depth)
    return {
        "data": {
            "target": chain.target,
            "prerequisites": chain.prerequisites,
            "depth": chain.depth,
        }
    }


# --- Knowledge Gaps ---


@router.get("/gaps")
async def get_knowledge_gaps(
    user_id: CurrentUserId,
    query_service=Depends(get_graph_query_service),
) -> dict:
    """Detect knowledge gaps — unreached but connected concepts (KG-05)."""
    gaps = await query_service.get_knowledge_gaps(user_id)
    return {
        "data": [
            {
                "conceptId": g.concept_id,
                "conceptName": g.concept_name,
                "importance": round(g.importance, 4),
                "connectedKnown": g.connected_known,
            }
            for g in gaps
        ]
    }


# --- Graph Rebuild ---


@router.post("/rebuild")
async def rebuild_graph(user_id: CurrentUserId) -> dict:
    """Trigger a full rebuild of the user's knowledge graph."""
    from app.workers.kg_tasks import rebuild_knowledge_graph  # noqa: PLC0415
    task = rebuild_knowledge_graph.delay(user_id)
    return {"data": {"taskId": task.id, "status": "dispatched"}}
