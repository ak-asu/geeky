"""Knowledge Graph query service — graph algorithms and learning path generation.

Uses NetworkX for in-memory graph algorithms: PageRank, shortest path,
community detection, prerequisite chains (KG-04, KG-05).
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

import networkx as nx

if TYPE_CHECKING:
    from app.config import Settings
    from app.repositories.concept_repo import ConceptRepository
    from app.repositories.relationship_repo import RelationshipRepository

logger = logging.getLogger(__name__)


@dataclass
class KGSummary:
    """Summary statistics for a user's knowledge graph."""
    node_count: int = 0
    edge_count: int = 0
    top_concepts: list[dict] = field(default_factory=list)
    community_count: int = 0


@dataclass
class LearningPath:
    """Ordered sequence of concepts from source to target."""
    source: str
    target: str
    path: list[dict] = field(default_factory=list)
    total_weight: float = 0.0
    found: bool = False


@dataclass
class PrerequisiteChain:
    """Chain of prerequisite concepts for a target concept."""
    target: str
    prerequisites: list[dict] = field(default_factory=list)
    depth: int = 0


@dataclass
class KnowledgeGap:
    """Concepts the user hasn't mastered that are reachable from known concepts."""
    concept_id: str
    concept_name: str
    importance: float = 0.0
    connected_known: list[str] = field(default_factory=list)


class GraphQueryService:
    """Query service for knowledge graph operations.

    Loads user's KG from Firestore into a NetworkX DiGraph for algorithm execution.
    The graph is built on-demand per query (not cached long-term since it's per-user).

    Dependencies:
    - concept_repo: Access to KG nodes
    - relationship_repo: Access to KG edges
    - settings: Algorithm parameters
    """

    def __init__(
        self,
        *,
        concept_repo: ConceptRepository,
        relationship_repo: RelationshipRepository,
        settings: Settings,
    ) -> None:
        self._concept_repo = concept_repo
        self._relationship_repo = relationship_repo
        self._settings = settings

    async def get_summary(self, user_id: str) -> KGSummary:
        """Get summary statistics for the user's KG."""
        graph, concept_map = await self._load_graph(user_id)

        if graph.number_of_nodes() == 0:
            return KGSummary()

        # PageRank to find most important concepts
        pagerank = nx.pagerank(
            graph, alpha=self._settings.kg_pagerank_damping
        )
        top_nodes = sorted(pagerank.items(), key=lambda x: x[1], reverse=True)[:10]
        top_concepts = [
            {
                "id": node_id,
                "name": concept_map.get(node_id, {}).get("name", ""),
                "importance": round(score, 4),
            }
            for node_id, score in top_nodes
        ]

        # Community detection
        try:
            undirected = graph.to_undirected()
            communities = nx.community.louvain_communities(
                undirected, resolution=self._settings.kg_community_resolution
            )
            community_count = len(communities)
        except Exception:
            community_count = 0

        return KGSummary(
            node_count=graph.number_of_nodes(),
            edge_count=graph.number_of_edges(),
            top_concepts=top_concepts,
            community_count=community_count,
        )

    async def get_learning_path(
        self, user_id: str, source_id: str, target_id: str
    ) -> LearningPath:
        """Find the optimal learning path between two concepts (KG-04)."""
        graph, concept_map = await self._load_graph(user_id)

        source_name = concept_map.get(source_id, {}).get("name", source_id)
        target_name = concept_map.get(target_id, {}).get("name", target_id)

        if source_id not in graph or target_id not in graph:
            return LearningPath(source=source_name, target=target_name, found=False)

        try:
            # Use Dijkstra with inverted weights (stronger connections = shorter path)
            path_nodes = nx.shortest_path(
                graph, source=source_id, target=target_id, weight="inv_weight"
            )
            total_weight = nx.shortest_path_length(
                graph, source=source_id, target=target_id, weight="inv_weight"
            )

            path = [
                {
                    "id": node_id,
                    "name": concept_map.get(node_id, {}).get("name", ""),
                    "entity_type": concept_map.get(node_id, {}).get("entity_type", "concept"),
                }
                for node_id in path_nodes
            ]

            return LearningPath(
                source=source_name,
                target=target_name,
                path=path,
                total_weight=round(total_weight, 4),
                found=True,
            )

        except nx.NetworkXNoPath:
            return LearningPath(source=source_name, target=target_name, found=False)

    async def get_prerequisites(self, user_id: str, concept_id: str, max_depth: int = 5) -> PrerequisiteChain:
        """Get the prerequisite chain for a concept (KG-04).

        Traverses 'prerequisite' edges backwards from the target concept.
        """
        graph, concept_map = await self._load_graph(user_id)

        target_name = concept_map.get(concept_id, {}).get("name", concept_id)

        if concept_id not in graph:
            return PrerequisiteChain(target=target_name)

        # BFS traversal following prerequisite edges in reverse
        prerequisites: list[dict] = []
        visited: set[str] = {concept_id}
        queue: list[tuple[str, int]] = [(concept_id, 0)]

        while queue:
            current, depth = queue.pop(0)
            if depth >= max_depth:
                continue

            # Find predecessors with prerequisite edges
            for predecessor in graph.predecessors(current):
                edge_data = graph.get_edge_data(predecessor, current)
                if (
                    edge_data
                    and edge_data.get("type") == "prerequisite"
                    and predecessor not in visited
                ):
                    visited.add(predecessor)
                    prerequisites.append({
                        "id": predecessor,
                        "name": concept_map.get(predecessor, {}).get("name", ""),
                        "depth": depth + 1,
                    })
                    queue.append((predecessor, depth + 1))

        # Sort by depth (most foundational first)
        prerequisites.sort(key=lambda x: -x["depth"])

        return PrerequisiteChain(
            target=target_name,
            prerequisites=prerequisites,
            depth=max(p["depth"] for p in prerequisites) if prerequisites else 0,
        )

    async def get_knowledge_gaps(self, user_id: str) -> list[KnowledgeGap]:
        """Detect knowledge gaps — unreached nodes connected to known concepts (KG-05)."""
        graph, concept_map = await self._load_graph(user_id)

        if graph.number_of_nodes() == 0:
            return []

        # Get concepts with mastery state
        all_concepts = await self._concept_repo.get_all(user_id)
        known_ids = {
            c.id for c in all_concepts
            if c.mastery_state in ("learned", "mastered", "review")
        }
        unknown_ids = {
            c.id for c in all_concepts
            if c.mastery_state in ("unknown", "new")
        } & set(graph.nodes())

        # Find unknown concepts that are reachable from known concepts
        gaps: list[KnowledgeGap] = []
        pagerank = nx.pagerank(graph, alpha=self._settings.kg_pagerank_damping)

        for uid in unknown_ids:
            neighbors = set(graph.predecessors(uid)) | set(graph.successors(uid))
            connected_known = [n for n in neighbors if n in known_ids]
            if connected_known:
                gaps.append(KnowledgeGap(
                    concept_id=uid,
                    concept_name=concept_map.get(uid, {}).get("name", ""),
                    importance=pagerank.get(uid, 0.0),
                    connected_known=[
                        concept_map.get(n, {}).get("name", "")
                        for n in connected_known
                    ],
                ))

        # Sort by importance (most important gaps first)
        gaps.sort(key=lambda g: -g.importance)
        return gaps

    async def get_related_concepts(
        self, user_id: str, concept_id: str, limit: int = 10
    ) -> list[dict]:
        """Get concepts related to a given concept, ranked by connection strength."""
        graph, concept_map = await self._load_graph(user_id)

        if concept_id not in graph:
            return []

        neighbors: list[dict] = []
        for neighbor in set(graph.predecessors(concept_id)) | set(graph.successors(concept_id)):
            # Get edge weight (check both directions)
            weight = 0.0
            edge_type = "related"
            if graph.has_edge(concept_id, neighbor):
                data = graph.get_edge_data(concept_id, neighbor)
                weight = max(weight, data.get("weight", 0.0))
                edge_type = data.get("type", "related")
            if graph.has_edge(neighbor, concept_id):
                data = graph.get_edge_data(neighbor, concept_id)
                weight = max(weight, data.get("weight", 0.0))
                edge_type = data.get("type", "related")

            neighbors.append({
                "id": neighbor,
                "name": concept_map.get(neighbor, {}).get("name", ""),
                "relation_type": edge_type,
                "strength": round(weight, 4),
            })

        neighbors.sort(key=lambda x: -x["strength"])
        return neighbors[:limit]

    async def _load_graph(self, user_id: str) -> tuple[nx.DiGraph, dict[str, dict]]:
        """Load user's KG from Firestore into a NetworkX DiGraph.

        Returns (graph, concept_map) where concept_map is id -> {name, entity_type}.
        """
        concepts = await self._concept_repo.get_all(user_id)
        edges = await self._relationship_repo.get_all(user_id)

        graph = nx.DiGraph()
        concept_map: dict[str, dict] = {}

        for concept in concepts:
            graph.add_node(concept.id)
            concept_map[concept.id] = {
                "name": concept.name,
                "entity_type": concept.entity_type,
                "mastery_state": concept.mastery_state,
                "importance_score": concept.importance_score,
            }

        for edge in edges:
            if edge.source_id in graph and edge.target_id in graph:
                inv_weight = 1.0 / max(edge.strength, 0.01)
                graph.add_edge(
                    edge.source_id,
                    edge.target_id,
                    weight=edge.strength,
                    inv_weight=inv_weight,
                    type=edge.type,
                    confidence=edge.confidence,
                )

        return graph, concept_map
