# Design Decisions & Tradeoff Analysis for Geeky

This document captures key architectural decisions, tradeoffs analyzed, and reasoning for Geeky's short-form content, knowledge graph, and learning path systems.

---

## 1. SHORT-FORM CONTENT GENERATION PIPELINE

### Decision 1.1: Fixed-Size Chunking vs Semantic Chunking

| Criterion | Fixed-Size | Semantic | Decision |
|-----------|-----------|----------|----------|
| **Implementation Complexity** | Simple (tokenize) | Complex (clustering) | Fixed-Size |
| **Processing Speed** | Fast (O(n)) | Slower (O(n²) for clustering) | Fixed-Size |
| **Semantic Coherence** | Okay (may split sentences) | Excellent | Fixed-Size |
| **For Short Content** | Good enough | Overkill | Fixed-Size |
| **Cost** | Low | High | Fixed-Size |

**Rationale:**
- Geeky shorts are 5-15 minutes, typically single-topic
- Fixed-size chunking with sentence boundary awareness is sufficient
- No complex semantic clustering needed for coherent videos
- Trade short coherence for implementation simplicity and speed

**Implementation:**
```python
# Fixed-size with sentence boundary awareness
chunk_size = 512 tokens
for i in range(0, len(tokens), chunk_size):
    chunk = tokens[i:i+chunk_size]
    # Backtrack to sentence boundary if needed
    while not ends_at_sentence(chunk[-1]):
        chunk = chunk[:-1]
    yield chunk
```

---

### Decision 1.2: KG Integration Timing (During vs After Extraction)

| Aspect | During Extraction | After Chunking | Decision |
|--------|------------------|-----------------|----------|
| **Entity Duplication** | Prevented in-prompt | Deduped post-processing | Hybrid |
| **Latency** | Higher (complex prompts) | Lower | After |
| **Accuracy** | Better (contextual) | Worse | During |
| **Cost** | Higher token usage | Lower | After |
| **Implementation** | Single pass | Two-pass | Hybrid |

**Selected Approach: HYBRID**

**Real-Time Layer:**
1. Extract entities with KG context in prompt
2. Show user "Found 15 new concepts" preview
3. User confirms scope (deduplication prevents them seeing duplicates)

**Batch Layer:**
1. Consume extracted entities
2. Run full NER/EL independently
3. Post-process deduplication (semantic + topology)
4. Merge into KG

**Rationale:**
- Real-time preview prevents user-facing duplication (critical UX)
- Batch layer ensures accuracy (full NER pass)
- Hybrid = best of both worlds
- User confirmation gate = checkpoint for quality

---

### Decision 1.3: Real-Time KG Preview vs Batch Processing

| Dimension | Real-Time | Batch | Decision |
|-----------|-----------|-------|----------|
| **User Feedback** | Immediate ("Found 15 concepts") | Delayed (next day) | Real-Time |
| **Infrastructure Cost** | High (always-on) | Low (scheduled jobs) | Batch |
| **Latency** | <100ms for preview | <1s for final | Real-Time + Batch |
| **Accuracy** | Medium (quick extraction) | High (full processing) | Batch |

**Selected Approach: REAL-TIME PREVIEW + BATCH FINALIZATION**

```
User Action: Upload short
  ↓
Real-Time (<100ms):
  Quick entity extraction → Show preview → User confirms
  ↓
Batch (hourly):
  Full NER/EL → Dedup → KG merge → Path recomputation
```

**Rationale:**
- Real-time preview critical for UX (users expect immediate feedback)
- Batch processing ensures accuracy (full pipeline)
- Compromise on infrastructure: real-time is cheap extraction only, not full KG update
- Users get interactive experience without paying full cost

---

## 2. ENTITY DEDUPLICATION STRATEGY

### Decision 2.1: Similarity Metric Selection

| Metric | Use Case | Accuracy | Cost | Decision |
|--------|----------|----------|------|----------|
| **String (Jaro-Winkler)** | Typos, variations | 70% | Low | Required |
| **Semantic (Embeddings)** | Synonyms, rephrasings | 85% | Medium | Required |
| **Topology (Neighbors)** | Structural analysis | 65% | Low | Supplementary |
| **Single signal** | Baseline | 60-75% | Low | Not sufficient |
| **Composite (weighted)** | Production | 92%+ | Medium | Selected |

**Selected Approach: COMPOSITE SCORING**

```python
score = 0.3*string + 0.5*semantic + 0.2*topology

# Thresholds:
> 0.95: Auto-merge (low false positive risk)
0.80-0.95: Human review (borderline cases)
< 0.80: Create alias (safer for precision)
```

**Rationale:**
- Single metrics insufficient (too many false positives/negatives)
- Weighted combination leverages different signals
- Semantic similarity most important (0.5 weight) - catches synonyms
- String similarity secondary (0.3 weight) - catches typos
- Topology supplementary (0.2 weight) - structural validation
- Thresholds conservative to avoid data loss

**Benchmarks from Literature:**
- Production systems achieve 92-95% accuracy with composite scoring
- Amazon Neptune reports 80.5% F1 on 2.5M node KGs
- Most errors are false negatives (missed duplicates), not false positives

---

### Decision 2.2: Deduplication Confidence Thresholds

| Decision Threshold | Automation Level | Human Review | Risk |
|-------------------|------------------|--------------|------|
| > 0.99 | Auto-merge | None | Very Low (but misses duplicates) |
| > 0.95 | Auto-merge | None | Low |
| > 0.80 | Review queue | Yes | Medium |
| > 0.70 | Create alias only | Yes | High (false duplicates) |

**Selected Thresholds:**
- **Auto-merge: > 0.95** (high confidence)
- **Review queue: 0.80-0.95** (human validation needed)
- **Create alias: < 0.80** (preserve both, link them)

**Rationale:**
- Merging is destructive (hard to undo), so conservative threshold
- 0.95 threshold = <5% false positive risk
- Review queue catches borderline cases (human expertise valuable)
- Alias creation safe option for uncertain cases (preserves data)
- Can always merge later after human confirmation

---

### Decision 2.3: Merge Operation Strategy

| Approach | Safety | Reversibility | Auditability | Decision |
|----------|--------|---------------|--------------|----------|
| **Destructive merge** | Low (data loss) | Poor | Poor | No |
| **Merge with deprecation** | Medium | Good | Good | Selected |
| **Alias linking** | High | Excellent | Excellent | For low-confidence |

**Selected: Merge with Full Provenance**

```python
merge_event = {
    source_entity_id: "entity_123",
    target_entity_id: "entity_456",
    timestamp: "2025-02-09T14:30:00Z",
    merged_by: "auto_dedup",
    confidence: 0.97,
    old_state: {old_entity_dict},  # For rollback
    edges_added: 5,
    edges_updated: 3
}

# Source entity marked deprecated, not deleted
deprecate_entity(source_id, merged_into=target_id)
```

**Rationale:**
- Full provenance enables rollback if mistake detected
- Deprecation preserves history and lineage
- Audit trail important for data quality tracking
- Can query: "Show me all merged entities from batch X"

---

## 3. LEARNING PATH COMPUTATION

### Decision 3.1: Topological Sort Implementation

| Algorithm | Time | Space | Cycle Detection | Use Case |
|-----------|------|-------|-----------------|----------|
| **DFS-based** | O(V+E) | O(V) | No (need separate check) | Path generation |
| **Kahn's (BFS)** | O(V+E) | O(V) | Yes (natural) | Online, with validation |

**Selected: Kahn's Algorithm for Validation**

**Rationale:**
- DAG validation crucial (cycles = data error)
- Kahn's naturally detects cycles
- BFS-friendly for queue-based implementation
- Standard in production systems

**Usage:**
```
Short addition → Validate DAG → If valid, insert
               → If cycle, reject with explanation
```

---

### Decision 3.2: Full vs Partial Graph Traversal

| Scenario | Full Traversal | Partial (k-hop) | Decision |
|----------|---------------|-----------------|----------|
| **Graph Size** | < 1K nodes | > 10K nodes | Partial |
| **Query Latency** | Acceptable (V³) | Required (<100ms) | Partial |
| **Use Case** | Offline analysis | Real-time serving | Partial |
| **User Impact** | "Full curriculum" | "Next steps" | Partial |

**Selected: LIMITED DEPTH BFS (k-hop)**

```
Real-Time Path Recommendation:
  BFS with depth_limit = 2-3 hops
  • Time: O(k×E) ≈ O(k×V) for sparse graphs
  • Latency: <100ms
  • Returns: Immediate next 3 steps + "more to explore" indicator

Full Path Computation (Offline):
  BFS with depth_limit = 10 hops
  • Time: O(10×E) still manageable
  • Latency: <1s
  • Returns: Complete path to goal (if exists)
```

**Rationale:**
- Users don't need full curriculum view in real-time
- Most learning is local (immediate prerequisites/followups)
- 2-3 hops covers: current → next → breadth options
- Offline full computation for planning/analysis
- k-hop limits solve scalability without sacrificing UX

**Real-World Analogy:**
- Khan Academy: Shows next topic, not full curriculum
- YouTube: Recommends next 3 videos, not entire playlist
- This matches user behavior (step-by-step learning)

---

### Decision 3.3: Path Caching Strategy

| Cache Level | TTL | Hit Rate Expected | Trade-off |
|-------------|-----|-------------------|-----------|
| **Hot (In-Memory)** | 1 hour | 70% | Fast but small |
| **Warm (Redis)** | 24 hours | 25% | Good for yesterday's users |
| **Cold (Compute)** | On-demand | 5% | Recompute cost |

**Selected: 3-LEVEL CACHE HIERARCHY**

```
Tier 1 (Hot):
  In-memory (Redis/Memcached)
  TTL: 1 hour
  Hit rate: 70% (active users)
  Cost: <$10/month

Tier 2 (Warm):
  Persistent cache (Redis)
  TTL: 24 hours
  Hit rate: 25% (casual users)
  Cost: <$50/month

Tier 3 (Compute):
  On-demand computation
  BFS path finding
  Cost: 50-100ms latency
```

**Invalidation Strategy:**
```
Event: KG updated (new edge/node)
  ↓
Find affected paths (tag-based)
  ↓
Delete from hot cache (immediate)
  ↓
Mark warm cache entry stale
  ↓
On next access: Recompute (lazy)
```

**Rationale:**
- 1-hour TTL matches user session duration
- 24-hour warm cache captures "check-in later" users
- Lazy recomputation avoids thundering herd
- Tag-based invalidation prevents cache coherency issues

---

### Decision 3.4: Path Update Notification

| Strategy | Intrusiveness | Adoption | Fatigue Risk |
|----------|--------------|----------|--------------|
| **Automatic replacement** | High | Low (forced) | High |
| **Passive notification** | Low | Low (might miss) | Low |
| **Opt-in redesign** | Medium | High (user choice) | Low |

**Selected: OPT-IN WITH A/B TESTING**

```
User action: New better path available
  ↓
Option 1: Accept new path (replaces current)
Option 2: Keep current path (dismiss)
Option 3: Compare side-by-side

Track: Acceptance rate, completion rate for each
```

**Rationale:**
- Respects user agency (they chose current path)
- Users who accept new path = data signal (good!)
- Can A/B test: "Better path found" vs "Expert recommends"
- Metrics: >20% acceptance rate = success threshold

---

## 4. HANDLING DYNAMIC CONTENT (Deletion & Addition)

### Decision 4.1: Content Deletion Approach

| Strategy | User Impact | Recovery | Selection |
|----------|------------|----------|-----------|
| **Silent deprecation** | None (works as-is) | Can't—path breaks | No |
| **Reroute to alternative** | Automatic update | Yes | Preferred |
| **Human curator review** | Delayed | Manual | Fallback |
| **Notify user, no action** | Notification only | User decides | No |

**Selected: REROUTE + FALLBACK**

```
Short deleted:
  ↓
Step 1: Find alternative path (auto rerouting)
  • If successful: Update path, don't notify (seamless)
  • If impossible: Go to Step 2

Step 2: Offer alternatives
  • Show 3 related shorts that cover same concepts
  • User chooses, we update path

Step 3: Queue for human curator
  • If no alternative found
  • Curator fills gap manually
```

**Rationale:**
- Seamless experience when auto-reroute succeeds
- User choice when alternatives exist
- Human involvement only when necessary
- Minimizes disruption to learning

---

### Decision 4.2: Content Addition Approach

| Approach | Effort | User Value | Learning |
|----------|--------|-----------|----------|
| **Ignore (no action)** | Low | Zero | No |
| **Add to recommendations** | Medium | High | Yes |
| **Offer path improvement** | High | Highest | Yes |

**Selected: OFFER PATH IMPROVEMENT (if beneficial)**

```
Short added:
  ↓
Extract concepts & prerequisites
  ↓
Check: Does this improve any existing user paths?
  • Shorter path?
  • Better coverage of prerequisites?
  • Higher quality rating?
  ↓
If yes: Notify user
  "Better learning path available: 5 steps → 4 steps"
  User can accept/dismiss
  ↓
If no: Silently index (available for future paths)
```

**Rationale:**
- Identifies genuinely improved paths (not just added content)
- Respects current user path (not forced change)
- Notification fatigue avoided (only when significant improvement)
- User choice = data signal (accept rate metric)

---

## 5. BATCH VS REAL-TIME DECISION MATRIX

| Layer | Approach | Latency | Cost | Quality | Selection |
|-------|----------|---------|------|---------|-----------|
| **Entity Extraction** | Real-time | <100ms | Low | Medium | Selected |
| **Entity Deduplication** | Batch | <1s | Low | High | Selected |
| **KG Merge** | Batch | Variable | Low | High | Selected |
| **Path Computation** | Real-time (cached) | <50ms | Low | High | Selected |
| **Path Invalidation** | Event-based | <500ms | Medium | High | Selected |
| **Full Path Recomputation** | Batch (nightly) | <1s | Low | High | Selected |

**Architecture Summary:**

```
REAL-TIME (Milliseconds):
  ✓ Entity extraction (preview)
  ✓ Path lookup (cached)
  ✓ Entity embedding

EVENT-BASED (<500ms):
  ✓ Cache invalidation (reactive)
  ✓ User notification

BATCH (Nightly):
  ✓ Deduplication (full accuracy)
  ✓ KG merge
  ✓ Path recomputation (all users)
  ✓ Cache warming
```

**Cost Estimate:**

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| Hot cache (Redis) | $10 | 5GB, 70% hit rate |
| KG storage (Firestore) | $30 | 10M nodes/edges |
| Batch compute | $20 | 2 hours/night, Cloud Run |
| Embedding API calls | $50 | Gemini at scale |
| **Total** | **$110** | Per 100K users |

---

## 6. RISK ASSESSMENT & MITIGATION

### Risk 6.1: Entity Deduplication Errors

**Risk:** Auto-merge creates false positive (loses data)

**Probability:** Low (5% at 0.95 threshold)

**Impact:** High (data permanently merged)

**Mitigation:**
1. Conservative threshold (0.95, not 0.85)
2. Deprecation-based merge (restore from audit log)
3. Weekly audit of merges (human review sample)
4. Alert on unusual merge rate (>10% in batch)

---

### Risk 6.2: Learning Path Staleness

**Risk:** Cache serves outdated path (KG changed but cache not invalidated)

**Probability:** Medium (tag-based invalidation incomplete)

**Impact:** Medium (user gets suboptimal recommendation)

**Mitigation:**
1. Tag-based invalidation (dependency tracking)
2. Periodic validation (check if path still valid)
3. User feedback loop (flag outdated paths)
4. Batch refresh (nightly recomputation)

---

### Risk 6.3: Content Deletion Cascade

**Risk:** Deleting short breaks many user paths

**Probability:** Low (depends on short importance)

**Impact:** High (many affected users)

**Mitigation:**
1. Dry-run deletion (show affected users first)
2. Curator review (don't allow automatic deletion)
3. Alternative path computation (attempt reroute)
4. Notification system (inform affected users)
5. Rollback capability (mark deprecated, don't delete)

---

## 7. MONITORING & ALERTING RULES

### Critical Metrics

| Metric | Target | Alert | Action |
|--------|--------|-------|--------|
| Cache hit rate | >70% | <60% | Investigate eviction |
| Dedup accuracy | >95% | <90% | Review merges |
| Path latency (p95) | <100ms | >200ms | Scale cache/compute |
| KG update latency | <1s | >5s | Check bottleneck |
| User path breakage | <1% | >2% | Investigate deletions |

### Dashboard Queries

```sql
-- Cache performance
SELECT hit_rate, eviction_rate, avg_latency
FROM cache_metrics
WHERE service = 'learning_path'
ORDER BY timestamp DESC LIMIT 24;

-- Dedup decisions
SELECT decision, count(*), avg(score)
FROM dedup_decisions
WHERE timestamp > now() - interval '24 hours'
GROUP BY decision;

-- Path invalidations
SELECT reason, count(*)
FROM path_invalidations
WHERE timestamp > now() - interval '1 hour'
GROUP BY reason;
```

---

## 8. FUTURE SCALABILITY CONSIDERATIONS

### If Scaling to 1M Users

| Component | Current Approach | Scaling Strategy |
|-----------|-----------------|------------------|
| Path caching | Redis | Distributed Redis cluster |
| KG storage | Firestore | Graph database (Neo4j) |
| Batch compute | Cloud Run | Cloud Dataflow (parallel) |
| Entity extraction | Single-region | Multi-region load balance |
| Notifications | Direct | Message queue (Pub/Sub) |

### Potential Optimizations

1. **Learning to Rank**: Use ML to score candidate paths, not just BFS
2. **Graph Embedding**: Pre-compute node embeddings for faster similarity
3. **Stream Processing**: Continuous path updates (Kafka → Flink)
4. **Caching Strategy**: Segment users (VIP hot cache, casual warm cache)

---

## 9. IMPLEMENTATION ROADMAP

### Phase 1 (Weeks 1-4): Foundation
- [ ] Real-time entity extraction service
- [ ] Batch NER/EL pipeline
- [ ] Basic deduplication (string + semantic)
- [ ] KG merge operations with provenance
- [ ] Learning path BFS computation

**Milestone:** Can extract, deduplicate, and compute paths

### Phase 2 (Weeks 5-8): Optimization
- [ ] 3-level cache implementation
- [ ] Tag-based cache invalidation
- [ ] Content deletion handling
- [ ] Performance testing and tuning

**Milestone:** >70% cache hit rate, <100ms path latency

### Phase 3 (Weeks 9-12): Robustness
- [ ] Content addition optimization
- [ ] Monitoring & alerting
- [ ] Human review queue for borderline dedup
- [ ] User notification system

**Milestone:** Production-ready with ops support

### Phase 4 (Weeks 13+): Scaling
- [ ] Distributed caching
- [ ] Graph database migration (if needed)
- [ ] ML-based path ranking
- [ ] Multi-region support

---

## 10. DECISION LOG TEMPLATE

For future decisions, use this template:

```markdown
### Decision {number}: {Title}

**Context:**
- Problem statement
- Constraints
- Tradeoffs identified

**Alternatives Considered:**
1. Option A: [description] — Pros/cons
2. Option B: [description] — Pros/cons
3. Option C: [description] — Pros/cons

**Selected:** Option X

**Rationale:**
- Key reasons
- Why better than alternatives
- Tradeoffs accepted

**Risks & Mitigation:**
- Risk 1: [mitigation]
- Risk 2: [mitigation]

**Metrics to Track:**
- How we measure success
- Alert thresholds

**Review Date:** [When to revisit]
```

---

## References

- Topological Sort: Cormen et al., Introduction to Algorithms
- Deduplication Metrics: ACM SIGMOD 2023 papers on entity resolution
- Cache Invalidation: Meta Engineering Blog, "Cache Invalidation at Scale"
- Learning Paths: Khan Academy research on adaptive learning
- Graph Databases: Neo4j documentation on enterprise scaling
