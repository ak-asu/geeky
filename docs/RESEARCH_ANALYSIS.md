# Research Analysis: Short-Form Content, Knowledge Graphs, and Learning Paths

## Executive Summary

This document provides a comprehensive analysis of production systems and research papers addressing five key areas: short-form content generation pipelines, NER + entity linking + knowledge graph integration, learning path calculation, dynamic path adaptation, and existing recommendation solutions. The research covers academic foundations, production system patterns, and practical tradeoffs.

---

## 1. SHORT-FORM CONTENT GENERATION PIPELINES

### 1.1 Core Pipeline Architecture

Modern content generation pipelines follow a structured approach with multiple stages:

**Traditional Extract → Chunk → Summarize → Generate Flow:**
- **Extraction**: Full document input with metadata
- **Chunking**: Strategic document segmentation (critical preprocessing step)
- **Summarization**: Multi-level hierarchical summaries
- **Generation**: Coherent final content synthesis

### 1.2 Chunking Strategies (2025)

Different chunking approaches balance precision, recall, and computational cost:

**Proposition-Based Chunking (Precision-Focused)**
- Extracts atomic, claim-level statements from each sentence
- Uses LLMs with low temperature (~0.2) for consistency
- Maximum token size: ~256 tokens per proposition
- Groups into chunks until ~500-word capacity or topic shift
- **Strength**: High-precision retrieval for RAG systems
- **Weakness**: Higher computational cost during extraction

**Semantic Cluster Chunking (Topic-Focused)**
- Forms coherent, topic-based units
- Uses embedding-based clustering (TF-IDF + k-means)
- Splits at semantic/meaning shifts
- **Strength**: Maintains topic coherence
- **Weakness**: Requires careful embedding model selection

**Fixed-Size Chunking (Baseline)**
- Splits by token/character count
- Simple implementation
- **Weakness**: Ignores semantic boundaries, may split coherent ideas

**Sliding Window Chunking**
- Overlapping chunks for context preservation
- Good for retrieval-augmented generation
- Requires overlap ratio tuning

### 1.3 Multi-Level Summarization

Hierarchical approach for documents exceeding model token limits:

```
Document → Chunk 1 → Summary 1
        → Chunk 2 → Summary 2
        → Chunk N → Summary N
        ↓
    Aggregate Summaries → Final Document Summary
```

**Phases:**
1. **Extractive Preprocessing**: Identify salient content (removes noise)
2. **Abstractive Generation**: Produce concise, coherent summaries
3. **Aggregation**: Combine chunk summaries into coherent narrative

**Patterns:**
- **Map-Reduce**: Summarize chunks in parallel, reduce to final summary
- **Map-Rerank**: Generate multiple summaries, rank and select best
- **EACSS** (Extractive + Abstractive Compression Seq2Seq): Combine extractive and abstractive stages

### 1.4 Knowledge Graph Integration During Extraction vs After

**Integration Timing Decision Matrix:**

| Aspect | During Extraction | After Chunking |
|--------|------------------|-----------------|
| **Entity Detection** | Early LLM call with KG context | Separate NER pass |
| **Deduplication** | In-context examples prevent dupes | Post-processing merge |
| **Latency** | Higher (complex prompts) | Lower (simple prompts) |
| **Accuracy** | Better (contextual linking) | Worse (without context) |
| **Flexibility** | Tighter coupling | Loosely coupled |
| **Cost** | Higher token usage | Lower |

**Hybrid Approach (Recommended):**
1. Extract with KG context in prompt (e.g., "Known entities: ...") to prevent duplication
2. Generate chunk embeddings for semantic validation
3. Post-process with entity resolution for final deduplication
4. Update KG incrementally as batches complete

### 1.5 Real-Time KG Preview vs Batch Processing

**Real-Time KG Preview**
- Validates entities/relationships as chunks arrive
- Enables early deduplication detection
- User sees potential KG structure during content ingestion
- **Best for**: Interactive platforms, user-facing validation

**Batch Processing KG Updates**
- Accumulates changes, processes nightly/hourly
- Leverages batch economies of scale
- Simpler, more cost-effective infrastructure
- **Best for**: Content archives, non-interactive systems

**Hybrid Approach (Production Standard):**
```
Real-Time Fast Path:
  Content arrives → Quick entity extraction → Preview KG
              ↓
         (User confirms/edits)
              ↓
Batch Processing:
  Accumulated chunks → Full NER/EL → Dedup → Final KG update
```

### 1.6 Deduplication and Merging Strategies

**String-Based Similarity**
- Levenshtein distance, Jaro-Winkler
- Fast, simple
- Poor for semantic variations ("ML" vs "Machine Learning")

**Semantic Similarity (Embedding-Based)**
- Embed entity names and descriptions
- Cosine similarity in vector space
- Captures semantic relationships
- Requires tuning similarity threshold (typically 0.8-0.9)

**Graph Topology-Based**
- Consider connection patterns in existing KG
- Two entities are likely duplicates if they connect to same neighbors
- Jaccard similarity of neighbor sets
- **Strong signal** for hierarchical relationships

**Hybrid Scoring**
- Weight multiple signals: name similarity (0.3) + semantic similarity (0.5) + topology (0.2)
- Human review for borderline cases (typically >80% confidence)

**Merging Operations**
1. Identify duplicate candidates (clustering)
2. Compute merge score (weighted signals)
3. High confidence (>95%): Auto-merge with provenance tracking
4. Borderline (80-95%): Queue for human review
5. Low confidence (<80%): Create link/alias instead of merge

---

## 2. NER + ENTITY LINKING + KNOWLEDGE GRAPH

### 2.1 Real-Time Entity Validation and KG Updates

**Modern Approach (2025):**

LLMs with enhanced thinking chains and self-validation mechanisms:
1. Extract candidate entities from text
2. Perform logical validation on extracted content after reasoning
3. Validate against entity homonym database
4. Apply text vector similarity comparison
5. Update KG with validated entities

**Architecture:**
```
Text → LLM NER → Candidate Entities
              ↓
        Self-Validation (Thinking)
              ↓
        Homonym Disambiguation
              ↓
        Vector Similarity Check
              ↓
        KG Update (with provenance)
```

### 2.2 Entity Deduplication: Similarity Metrics

**String Similarity Metrics**
- Levenshtein Distance: Edit operations needed
- Jaro-Winkler: Weighted prefix matching
- Time Complexity: O(n*m) where n, m are string lengths
- **Use when**: Typos, minor variations

**Semantic Similarity (Embeddings)**
- BERT-based entity embeddings
- Dense vector representations (e.g., 768 dimensions)
- Cosine similarity in embedding space
- **Threshold**: 0.8-0.9 for high confidence
- Works well for: "CNN" vs "Convolutional Neural Network"

**Graph-Based Similarity**
- Jaccard Similarity of neighbor sets: |N(a) ∩ N(b)| / |N(a) ∪ N(b)|
- Common neighbor count
- Edge overlap ratio
- **Signal**: Entities with identical neighborhoods are likely duplicates

**Composite Scoring (Production Standard)**
```python
score = (
    0.3 * string_similarity +
    0.5 * semantic_similarity +
    0.2 * graph_topology_similarity
)
decision = {
    score > 0.95: "auto_merge",
    0.80 < score ≤ 0.95: "review_queue",
    score ≤ 0.80: "create_link"
}
```

### 2.3 Systems with Preview-Before-Commit Approach

**Graphiti (Zep AI) - Real-Time KG Evolution**
- Incremental updates as new information arrives
- Stores facts + temporal context
- Neo4j storage with agent-facing API
- Stream-efficient with incremental updates
- Designed for long-running agents with continuous learning
- **Key Feature**: Unlike batch GraphRAG, handles real-time evolving memory

**Microsoft GraphRAG**
- Graph-based retrieval augmented generation
- Batch-based extraction (not real-time)
- Hierarchical summarization from KG
- Good for document-centric retrieval

**Production Pattern:**
```
Real-Time Preview (Validation Layer):
  Content → Quick extraction → Show user "Found: 15 new entities"
                            ↓
                     User confirms scope
                            ↓
Deferred Processing (Commit Layer):
  Batch entities → NER/EL → Dedup → Merge → KG update
```

### 2.4 Entity Alignment in Multi-Graph Scenarios

**Cross-Graph Entity Alignment:**
- Discovering identical entity pairs across different KGs
- Critical for knowledge fusion
- Embedding-based methods: Learn vector representations preserving similarity
- Supervised/unsupervised/semi-supervised approaches

**Benchmarked Results:**
- High-quality linkage: 80.5% F1 score, 60% recall (at 95% precision)
- Tested on KGs with 2.5+ million nodes
- Practical production systems achieve these metrics

---

## 3. LEARNING PATH CALCULATION

### 3.1 Prerequisite Graph as Directed Acyclic Graph (DAG)

**Structure:**
- Nodes: Learning objectives, topics, courses
- Directed edges: Prerequisite relationships (A → B means A is prerequisite for B)
- Acyclic: No circular dependencies (enforced by validation)
- Metadata: Difficulty, time estimates, completion rates

**DAG Properties:**
- Always has topological ordering (linear sequence respecting all prerequisites)
- Multiple valid orderings possible (any one is valid)
- Cycles indicate conflicting prerequisites (data error)

### 3.2 Topological Sort Algorithms for Path Generation

**Depth-First Search (DFS) Based**
```
1. For each unvisited vertex:
   - Perform DFS, visiting all dependencies
   - Push vertex to stack AFTER processing all descendants
2. Pop stack elements to get topological order
```
- **Complexity**: O(V + E) where V = vertices, E = edges
- **Advantage**: Simple, intuitive
- **Use case**: Standard prerequisite ordering

**Kahn's Algorithm (BFS Based)**
```
1. Compute in-degree for all vertices (prerequisite count)
2. Queue all vertices with in-degree 0
3. While queue not empty:
   - Remove vertex from queue, add to result
   - Decrease in-degree of all dependent vertices
   - If in-degree becomes 0, enqueue vertex
```
- **Complexity**: O(V + E)
- **Advantage**: Detects cycles naturally
- **Use case**: Streaming/online topological sort

**Practical Implementation:**
```python
# Both algorithms process in O(V + E)
# Choose based on implementation complexity, not performance
# DFS easier for single path generation
# Kahn's better for detecting cyclic dependencies
```

### 3.3 Partial vs Full Graph Traversal

**Full Traversal Strategy**
- Compute shortest path from current state to all possible goals
- Algorithm: Floyd-Warshall (O(V³)) or Bellman-Ford
- **When necessary**:
  - Small graphs (< 1000 nodes)
  - Need to answer arbitrary path queries
  - User can choose any goal

**Partial/Limited Traversal (Production Standard)**
- K-hop neighbors: Only traverse k edges from current node
- Breadth-first with depth limit
- **When appropriate**:
  - Large graphs (> 10,000 nodes)
  - Most learning is local (immediate prerequisites/followups)
  - Real-time response requirements

**Windowed Computation**
```
User at Node A, Goal Node Z:

1. BFS from A with depth limit d
   - If Z reachable within d hops: use that path
   - Otherwise: recommend next step (node at hop d closest to Z)

2. When user completes step:
   - Recompute from new position
   - User doesn't see full path, just next guided steps
```

**Depth Limits by Use Case:**
- Real-time recommendations: 2-3 hops
- Offline planning: 5-10 hops
- Full curriculum view: Unlimited

### 3.4 Path Computation with Dynamic Updates

**Problem:**
When shorts/nodes are added, deleted, or modified, previously computed paths become stale.

**Solutions:**

**Event-Based Cache Invalidation**
```
Trigger: Node deleted, edge added/removed
Action:
  1. Identify affected paths (dependency graph)
  2. Invalidate cached paths containing affected nodes
  3. Recompute on next access (lazy evaluation)
  4. Or batch recompute during off-peak
```

**Incremental Update Strategy**
```
For added node X:
  - Analyze neighbors of X
  - Determine if X improves any existing paths
  - If yes: mark path for recomputation
  - Insert X into data structure

For deleted node X:
  - Find all paths containing X
  - Compute alternative routes using existing nodes
  - Mark for recomputation if no alternative exists
  - Flag for user notification
```

**Reactive/Incremental Systems**
- Materialize-style approach: Track change propagation
- When node Y changes, automatically update all dependent computations
- Requires dependency graph of all computed paths
- **Cost**: Higher upfront tracking cost, faster updates

### 3.5 Real-World Examples

**Khan Academy - Adaptive Prerequisites**
- DAG of learning objects across grades 3-Geometry
- Adaptive paths based on MAP Growth scores
- Mastery-based progression
- Fast skipping if mastered, scaffolding if struggling
- Per-student customization, not just prerequisites

**Coursera - Course Prerequisites and Learning Paths**
- Courses form DAG with explicit prerequisites
- Concept maps using directed edges for prerequisite relationships
- Topological sort generates valid course sequences
- Weak concept learning: Simplify paths based on learner's error rates
- Algorithm: Reduce to minimum necessary prerequisites for learner

**LeetCode - Study Plans**
- Curated problem sequences (not organic graph)
- Time-based gates: Next day's problems unlock daily
- Reset if deadline missed (forces retry)
- Less about prerequisites, more about structured curriculum
- Graph exists but is managed manually by content team

---

## 4. DYNAMIC PATH ADAPTATION

### 4.1 Real-Time Path Recomputation vs Incremental Updates

**Real-Time Full Recomputation**
- On every user action, recompute relevant paths
- Algorithm: BFS/DFS from current position
- Complexity: O(V + E) per user action
- **Cost**: High (doesn't scale to millions of users)
- **Benefit**: Always optimal paths

**Incremental Update Strategy**
- Cache computed paths
- Track which nodes affect which cached paths
- On change: update only affected caches
- **Cost**: Moderate (depends on change frequency)
- **Benefit**: Scalable, predictable latency

**Hybrid Approach (Recommended)**
```
Small graphs (<10K nodes):
  → Real-time recomputation (simple, sufficient)

Medium graphs (10K-1M nodes):
  → Cached paths + event-based invalidation
  → Lazy or batch recomputation

Large graphs (>1M nodes):
  → Fixed cached recommendations
  → Windowed local computation
  → Nightly batch recomputation for new users
```

### 4.2 Cache Invalidation Strategies

**Tag-Based Invalidation (Best Practice)**
- Assign tags to cache entries based on graph dependencies
- When node changes: Invalidate all entries tagged with that node
- Example: Path[User1→Goal] tagged with nodes [A, B, C, D]
- Change to node B: Invalidate all paths tagged with B

```
Cache Entry: Path[user1→goal1] = [A→B→C→D]
Tags: {A, B, C, D, user1, goal1}
Change: Node B modified
Action: Invalidate all entries tagged with B
```

**Time-Based (TTL) Invalidation**
- Cache paths for fixed duration (e.g., 1 hour)
- Periodic refresh in background
- Simple, doesn't require dependency tracking
- **Weakness**: Stale paths still served until TTL expires

**Event-Based Invalidation (Modern)**
```
Dependency Graph Tracking:
  1. When path P1 is computed, record: P1 depends on {Nodes: A,B,C}
  2. When node B changes, automatically mark P1 invalid
  3. On next access: Recompute P1
  4. Optional: Batch invalidate all during off-peak
```

**Meta's Production Pattern**
- Facebook/Meta blog documents cache invalidation as "one of the hardest things"
- Solution: Dependency tracking at system level
- Every computed value tracks its inputs
- Change to input → automatic propagation to dependents
- Implemented in distributed systems for scale

### 4.3 Handling Deleted Shorts/Content

**Problem:** Short video deleted → paths depending on it break

**Solution 1: Rerouting**
```
Original Path: A → X (deleted) → C → Goal
New Path: A → [find alternative] → Goal

Algorithm:
  1. Identify nodes immediately before/after deleted node
  2. Find shortest path between them avoiding deleted node
  3. If exists: Use new path
  4. If not: Need different intermediate steps
```

**Solution 2: Gap Filling**
```
Detect: Missing node in path
Action: Recommend "related alternatives"
  - Next best path using different intermediate nodes
  - Multiple options ranked by relevance
  - User chooses preferred alternative
```

**Solution 3: Fallback Recommendations**
```
If no alternative path exists:
  1. Recommend "closest" nodes to deleted content
  2. Suggest learning from different angle
  3. Queue user for manual curator review
  4. Notify user: "Content updated, new recommendation sent"
```

**Implementation Pattern:**
```python
def handle_content_deletion(node_id, graph, user_paths):
    affected_paths = [p for p in user_paths if node_id in p.nodes]

    for path in affected_paths:
        idx = path.index(node_id)
        before, after = path.nodes[idx-1], path.nodes[idx+1]

        # Try rerouting
        new_segment = find_shortest_path(before, after, graph)
        if new_segment:
            path.replace_segment(idx, new_segment)
        else:
            # Try gap-filling
            alternatives = find_alternative_paths(before, after, graph)
            notify_user(user_id, "content_updated", alternatives)
```

### 4.4 Handling New Relevant Content

**Problem:** New short added → where does it fit in existing paths?

**Solution 1: Insertion Based on Prerequisite Relationships**
```
New node X arrives:
  1. Compute prerequisites of X (what must come before)
  2. Compute dependents of X (what should come after)
  3. For each existing path:
     - If path contains prereqs but not X: Can insert X
     - If path contains X's dependents: X should precede them
     - Insert X optimally (maintain difficulty gradient)
```

**Solution 2: Ranking New Content Against Existing Paths**
```
User at node A, goal node Z:
  1. Compute existing path P1: A → ... → Z
  2. New node X arrives
  3. Compute alternative path P2: A → ... → X → ... → Z
  4. Rank paths:
     - P1 length vs P2 length
     - P1 quality vs P2 quality (user satisfaction metrics)
     - P1 recency vs P2 (newer content often better)
  5. Recommend best path
```

**Solution 3: Real-Time Path Augmentation (Stream Processing)**
```
System: Graphiti-style incremental updates
  1. New content X added to system
  2. System computes how X affects all active paths
  3. For each user with path affected:
     - Check if new path through X is better
     - Notify user: "Better learning path available"
     - User can accept/dismiss
```

---

## 5. EXISTING RECOMMENDATION SOLUTIONS

### 5.1 Approach Comparison Matrix

| Approach | Mechanism | Latency | Scalability | Explainability | Best For |
|----------|-----------|---------|-------------|-----------------|----------|
| **Path-Based** | Explicit prerequisite chains | Low | Good | High | Structured curricula |
| **Graph-Based (GNN)** | Message passing on KG | Medium | Excellent | Medium | Rich relationships |
| **Matrix Factorization** | User-item embeddings | Low | Excellent | Low | Cold-start problems |
| **Collaborative Filtering** | User similarity | Medium | Good | Medium | Implicit feedback |
| **Hybrid (2025)** | Combined signals | Medium | Good | High | Production systems |

### 5.2 Path-Based Approaches

**Advantages:**
- Explicit prerequisite chains provide clear justification
- Users understand "why this recommendation"
- Works offline (deterministic computation)
- Handles domain requirements (must know X before Y)

**Implementation:**
```
1. Current node: A (user's state)
2. Target node: Z (user's goal)
3. Algorithm: Find shortest/best path A→Z
4. Return: Recommended next step (first edge)
5. Repeat as user progresses
```

**Limitations:**
- Requires explicit prerequisite data (not always available)
- Doesn't leverage user behavior (cold-start problem)
- Can't handle probabilistic relationships ("usually helps to know X")

### 5.3 Graph Neural Network Approaches

**Heterogeneous Graph Neural Networks (HGNNs)**
- Model diverse node types and edge types
- Example: Course nodes, prerequisite edges, learner nodes, completion edges
- Use hierarchical attention mechanisms (node-level, semantic-level)
- Meta-paths capture semantic relationships

**Architecture Example:**
```
Input: Heterogeneous graph
  - Node types: Courses, Topics, Learners, Skills
  - Edge types: PrerequisiteOf, Covers, CompletedBy, HasSkill

Layer 1 (Node-Level Attention):
  - For each node, weight neighbors by feature importance

Layer 2 (Semantic-Level Attention):
  - For each meta-path (e.g., Course→Topic→Course)
  - Weight different meta-paths by importance

Output: Node embeddings capturing structure + semantics
```

**Advantages:**
- Captures complex relationships beyond binary prerequisites
- Learns from user behavior patterns
- Handles implicit signals (enrollment time, dropout patterns)
- Can personalize based on learner profile

**Disadvantages:**
- Requires large training datasets
- Less interpretable ("black box" recommendations)
- Sensitive to graph structure changes

### 5.4 Matrix Factorization & Collaborative Filtering

**Matrix Factorization:**
```
User-Content matrix M:
  Rows: Users
  Cols: Learning objects
  Cells: Interaction (completed, time spent, score)

Factorization: M ≈ U × V^T
  U: User latent factors (K dimensions)
  V: Content latent factors (K dimensions)

Recommendation: Score(u, item) = U[u] · V[item]
```

**Strengths:**
- Scalable to large systems (Netflix uses this)
- Handles implicit feedback (views, time spent)
- Cold-start mitigation with side information

**Weaknesses:**
- Doesn't explain "why this"
- Requires large user base for effectiveness
- Limited by training data sparsity

### 5.5 Real-World Platform Patterns

**Netflix - Real-Time Content Recommendations**
- Real-time processing for immediate user reactions
- Matrix factorization for user-movie similarity
- 20% churn reduction using real-time enrichment
- Batch updates for catalog-wide recommendations
- **Key Decision**: Real-time for individual users, batch for global patterns

**Khan Academy - Adaptive Learning Paths**
- DAG prerequisites with mastery gates
- Adaptive based on MAP Growth scores
- Per-student customization
- Focus on next step (not full curriculum view)

**Coursera - Course Recommendation**
- Heterogeneous information networks
- Meta-path-guided graph convolutional networks
- Prerequisite relationships as directed edges
- Weak concept mining (identify gaps, recommend remedial content)

**Udemy - User-Behavior Driven**
- Collaborative filtering on enrollment data
- Content-based filtering on course metadata
- Blended recommendation (both signals)
- Personalized based on watch patterns

### 5.6 Production System Design Patterns

**Batch + Real-Time Hybrid (Industry Standard)**

```
Batch Pipeline (Daily, off-peak):
  1. Full user-content matrix updates
  2. Model retraining (hours of computation)
  3. Global recommendation model updates
  4. Pre-compute recommendations for top N users
  5. Push updates to serving layer

Real-Time Service (Always-on):
  1. Serve pre-computed recommendations
  2. React to immediate user actions (just watched)
  3. Handle cold-start with heuristics
  4. A/B test new algorithms
  5. Log interactions for next batch update
```

**Cache Strategy for Learning Paths:**
```
Hot Cache (In-Memory):
  - Active user paths
  - TTL: 1 hour
  - Hit rate: ~70%

Warm Cache (Redis):
  - Recent user paths
  - TTL: 24 hours
  - Hit rate: ~25%

Cold Cache (Database):
  - Historical paths
  - Recompute on demand
  - Hit rate: ~5%

When path changes:
  - Invalidate hot + warm caches
  - Recompute on next user interaction
```

### 5.7 Handling Dynamic Content in Recommendations

**Problem Scope:**
- Content (shorts) added/deleted/modified continuously
- Recommendations must adapt without staleness
- User experience should be seamless

**Layered Solution:**

**Layer 1: Content Change Detection**
```
Event Stream: Short added, deleted, edited
  ↓
  Process change, identify affected recommendations
  ↓
  Mark affected cache entries
```

**Layer 2: Impact Analysis**
```
Which paths does this content affect?
  - Direct: Paths containing this content
  - Indirect: Paths depending on prerequisites of this content
  - Potential: Paths that could use this content as improvement

Result: Set of affected users/paths
```

**Layer 3: Update Strategy**
```
If change affects active users:
  - Real-time path recomputation (milliseconds)
  - Notify user of path update

If change affects cached paths:
  - Lazy invalidation (recompute on next access)
  - Batch recomputation (during off-peak)

If change is significant (e.g., core concept):
  - Full global update of recommendation model
  - Happens nightly
```

**Layer 4: User Communication**
```
Transparent updates:
  "Your learning path has been updated with new content"
  "Better path found - see improved route"
  "Content updated - here's next best alternative"

Opt-in updates:
  Option to revert to previous path
  View old vs new path comparison
  Choose update timing (immediate vs next session)
```

---

## 6. SPECIFIC RECOMMENDATIONS FOR GEEKY PROJECT

### 6.1 Recommended Architecture

**Content Ingestion Pipeline:**
```
Short Added → Extract Entities (LLM + context)
           → Chunk + Embed
           → Real-time KG Preview (user confirmation)
           ↓
        (Batch Window: hourly/nightly)
           ↓
        Full NER/EL Pass
        Deduplication (semantic + topology)
        Graph Merge & Validation
        Learning Path Recalculation
```

**Learning Path Computation:**
```
User State: Current node + goal
  ↓
BFS with depth limit (2-3 hops):
  - Find immediate next steps
  - Lazy-load full path as user progresses

Cache Strategy:
  - Hot: Active user paths (1 hour TTL)
  - Warm: Recent paths (24 hour TTL)
  - Pattern: Daily batch recomputation for all users

Update Trigger:
  - Content added/deleted
  - User completes a short
  - User falls back to prerequisites
```

### 6.2 Entity Deduplication for Shorts

**Composite Similarity Score:**
```python
def deduplicate_score(entity_a, entity_b):
    return (
        0.3 * string_similarity(entity_a.name, entity_b.name) +
        0.5 * embedding_similarity(entity_a.description, entity_b.description) +
        0.2 * graph_topology_similarity(entity_a, entity_b)
    )

# Thresholds:
# > 0.95: Auto-merge (log provenance)
# 0.80-0.95: Human review queue
# < 0.80: Create alias link
```

### 6.3 Content Deletion Handling

**When Short is Deleted:**
1. Mark as deprecated (don't remove from KG, keeps history)
2. Find paths containing this short
3. Compute alternative paths (rerouting)
4. For paths with no alternative:
   - Flag for curator review
   - Recommend "related content"
   - Notify affected learners

### 6.4 Real-Time vs Batch Decision

**Real-Time:**
- Entity extraction preview (user-facing)
- Path computation for active users (on demand)
- Immediate response to user actions

**Batch (Nightly):**
- Full KG reconciliation and deduplication
- Learning model retraining (if using ML)
- Cache warming for next day
- Content quality validation

---

## References

### Chunking & Summarization
- [NVIDIA: Finding the Best Chunking Strategy](https://developer.nvidia.com/blog/finding-the-best-chunking-strategy-for-accurate-ai-responses/)
- [Cache-Craft: Managing Chunk-Caches for Efficient RAG (SIGMOD 2025)](https://skejriwal44.github.io/docs/CacheCraft_SIGMOD_2025.pdf)
- [Clinical Decision Support: Comparative Evaluation of Chunking](https://pmc.ncbi.nlm.nih.gov/articles/PMC12649634/)
- [Databricks: Quality Data Pipeline for RAG](https://docs.databricks.com/aws/en/generative-ai/tutorials/ai-cookbook/quality-data-pipeline-rag)

### Knowledge Graph Construction & NER
- [MDPI: Knowledge Graph Construction](https://www.mdpi.com/2076-3417/15/7/3727)
- [Neo4j: Entity Linking with Relik in LlamaIndex](https://neo4j.com/blog/developer/entity-linking-relationship-extraction-relik-llamaindex/)
- [UBIAI: NER in Knowledge Graphs](https://ubiai.tools/integrating-ner-with-knowledge-graphs-for-advanced-data-analytics-and-semantic-understanding/)
- [arXiv: LLM-empowered Knowledge Graph Construction Survey](https://arxiv.org/html/2510.20345v1)
- [Medium: Building Production-Ready Graph Systems in 2025](https://medium.com/@claudiubranzan/from-llms-to-knowledge-graphs-building-production-ready-graph-systems-in-2025-2b4aff1ec99a)

### Entity Deduplication & Semantic Resolution
- [Towards Data Science: Semantic Entity Resolution](https://towardsdatascience.com/the-rise-of-semantic-entity-resolution/)
- [AWS: Vector Similarity Search in Neptune](https://aws.amazon.com/blogs/database/find-and-link-similar-entities-in-a-knowledge-graph-using-amazon-neptune-part-2-vector-similarity-search/)
- [ScrapingAnt: Data Deduplication in Knowledge Graphs](https://scrapingant.com/blog/data-deduplication-and-canonicalization-in-scraped)
- [Nature: Automatic Record Deduplication with Learning](https://www.nature.com/articles/s41598-024-63242-1)

### Learning Path Recommendation
- [ResearchGate: Graph Theory for Learning Path Recommendation](https://www.researchgate.net/publication/257305821_Graph_theory_based_model_for_learning_path_recommendation)
- [MDPI: Personalized Learning Path Recommendation Survey](https://www.mdpi.com/2079-9282/15/1/238)
- [Nature: Personalized English Learning Path with Deep RL](https://www.nature.com/articles/s41598-025-17918-x)
- [Scirea: Learning Path Recommendation Based on Knowledge Graph](https://www.scirea.org/journal/PaperInformation?PaperID=13064)

### Topological Sort & DAGs
- [GeeksforGeeks: Topological Sorting](https://www.geeksforgeeks.org/dsa/topological-sorting/)
- [Wikipedia: Topological Sorting](https://en.wikipedia.org/wiki/Topological_sorting)
- [CS3 Data Structures: Topological Sort](https://opendsa-server.cs.vt.edu/ODSA/Books/CS3/html/GraphTopsort.html)

### Graph Neural Networks & Heterogeneous Graphs
- [PyG Documentation: Heterogeneous Graph Learning](https://pytorch-geometric.readthedocs.io/en/latest/notes/heterogeneous.html)
- [Nature: Iterative Heterogeneous Graph Learning for KG-based Recommendation](https://www.nature.com/articles/s41598-023-33984-5)
- [ACM: Heterogeneous Graph Contrastive Learning](https://dl.acm.org/doi/10.1145/3539597.3570484)
- [Distill.pub: A Gentle Introduction to Graph Neural Networks](https://distill.pub/2021/gnn-intro/)

### Cache Invalidation & Dynamic Updates
- [Meta: Cache Invalidation at Scale](https://engineering.fb.com/2022/06/08/core-data/cache-invalidation)
- [Medium: Cache Invalidation Strategies](https://medium.com/@shivanimutke2501/day-48-system-design-concept-cache-invalidation-strategies-de15e32020cf)
- [Materialize: Cache Invalidation with Redis](https://materialize.com/blog/redis-cache-invalidation/)
- [Skip: Cache Invalidation and Reactive Systems](https://skiplabs.io/blog/cache_invalidation)
- [arXiv: DynamicAdaptiveClimb Cache Replacement Policy](https://arxiv.org/html/2511.21235)

### Real-Time vs Batch Processing
- [SuperAGI: Batch vs Real-Time Data Enrichment](https://superagi.com/batch-processing-vs-real-time-data-enrichment-which-approach-is-right-for-your-business/)
- [ApplyingML: Real-Time Retrieval for Recommendations](https://applyingml.com/resources/real-time-recommendations/)
- [Branch Boston: Real-Time ML vs Batch ML](https://branchboston.com/real-time-ml-vs-batch-ml-when-to-use-each-approach/)
- [IEEE: Comparison of Real-Time and Batch Job Recommendations](https://ieeexplore.ieee.org/document/10054029/)

### RAG with Knowledge Graphs
- [Neo4j: RAG Tutorial on Knowledge Graphs](https://neo4j.com/blog/developer/rag-tutorial/)
- [DataCamp: Knowledge Graph RAG Applications](https://www.datacamp.com/tutorial/knowledge-graph-rag)
- [Databricks: Building KG RAG Systems](https://www.databricks.com/blog/building-improving-and-deploying-knowledge-graph-rag-systems-databricks)
- [Microsoft: GraphRAG](https://microsoft.github.io/graphrag/)
- [Hugging Face: RAG with Knowledge Graphs](https://huggingface.co/learn/cookbook/en/rag_with_knowledge_graphs_neo4j)
- [Nature: RAG Model Based on Knowledge Graphs](https://www.nature.com/articles/s41598-025-21222-z)

### Khan Academy & Real-World Examples
- [Khan Academy: Learning Paths Feature](https://districts.khanacademy.org/learning-paths)
- [Khan Academy: Algorithms Curriculum](https://cs-blog.khanacademy.org/2014/11/teaching-algorithms-on-khan-academy.html)

---

## Appendix: Algorithm Complexity Reference

| Algorithm | Time | Space | Notes |
|-----------|------|-------|-------|
| **Topological Sort (DFS)** | O(V+E) | O(V) | Path generation |
| **Topological Sort (Kahn)** | O(V+E) | O(V) | Cycle detection |
| **BFS (k-hop limited)** | O(k×E) | O(V) | Path recommendations |
| **Floyd-Warshall** | O(V³) | O(V²) | All-pairs shortest path |
| **Levenshtein Distance** | O(n×m) | O(n×m) | String similarity |
| **Embedding Similarity** | O(d) | O(1) | Cosine product (d = dimensions) |
| **Jaccard Similarity** | O(N) | O(N) | Set operations |

---

## Document Metadata

- **Compiled**: February 9, 2026
- **Scope**: Production systems, academic research, 2025 state-of-the-art
- **Target**: Geeky platform architecture decisions
- **Format**: Research synthesis with practical recommendations
