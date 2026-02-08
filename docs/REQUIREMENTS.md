# Geeky — Comprehensive Application Requirements

> A Flutter-based adaptive educational platform that transforms multimedia notes into bite-sized, interconnected learning articles ("Shorts"), organized into Modules, navigable via a Knowledge Graph, with adaptive learning paths that evolve based on user interactions.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Core Concepts & Glossary](#2-core-concepts--glossary)
3. [Functional Requirements](#3-functional-requirements)
   - 3.1 [Media Ingestion & Content Capture](#31-media-ingestion--content-capture)
   - 3.2 [Content Processing Pipeline](#32-content-processing-pipeline)
   - 3.3 [Shorts Management](#33-shorts-management)
   - 3.4 [Module Management](#34-module-management)
   - 3.5 [Knowledge Graph & Navigation](#35-knowledge-graph--navigation)
   - 3.6 [Adaptive Learning & Personalization](#36-adaptive-learning--personalization)
   - 3.7 [User Profiling & Modeling](#37-user-profiling--modeling)
   - 3.8 [Retention & Assessment](#38-retention--assessment)
   - 3.9 [RAG / Knowledge Query](#39-rag--knowledge-query)
   - 3.10 [Search & Discovery](#310-search--discovery)
   - 3.11 [User Interactions & Engagement](#311-user-interactions--engagement)
   - 3.12 [Social & Sharing](#312-social--sharing)
   - 3.13 [Notifications](#313-notifications)
   - 3.14 [Settings & Preferences](#314-settings--preferences)
   - 3.15 [Authentication & Profile](#315-authentication--profile)
   - 3.16 [Onboarding](#316-onboarding)
   - 3.17 [Offline & Sync](#317-offline--sync)
   - 3.18 [Analytics & Progress Tracking](#318-analytics--progress-tracking)
   - 3.19 [Content Source Management](#319-content-source-management)
   - 3.20 [Lifecycle Management](#320-lifecycle-management)
   - 3.21 [Browser Extension Companion](#321-browser-extension-companion)
4. [Non-Functional Requirements](#4-non-functional-requirements)
   - 4.9 [AI/ML Quality Metrics](#49-aiml-quality-metrics)
5. [User Stories](#5-user-stories)
6. [System Interactions & Automated Behaviors](#6-system-interactions--automated-behaviors)
7. [Data Entities Summary](#7-data-entities-summary)

---

## 1. Executive Summary

Geeky is a sophisticated, AI-driven educational platform that combines three core pillars:

1. **Content Ingestion & Processing** — Accept multimedia from diverse sources (shared media, manual uploads, URLs, RSS, newsletters), extract knowledge using AI (Gemini), and distill it into concise, focused learning articles ("Shorts").
2. **Knowledge Organization & Navigation** — Organize Shorts into a Knowledge Graph with hierarchical and lateral relationships, group them into Modules, and enable web-like traversal with dive-deeper / go-up / next / related navigation.
3. **Adaptive Learning & Personalization** — Continuously model user knowledge, strengths, weaknesses, and memory patterns; dynamically reorder the learning roadmap after every interaction; employ spaced repetition, quizzes, and probabilistic algorithms to maximize retention and comprehension.

The platform targets self-directed learners who consume content from many sources and want it synthesized, deduplicated, and presented in an adaptive, non-overwhelming format.

---

## 2. Core Concepts & Glossary

| Concept | Definition |
|---------|-----------|
| **Media / Note** | A raw piece of content ingested into the system — text, image, audio, video, link, or file. The atomic input unit. |
| **Chunk** | A semantically coherent segment of extracted text from a Note, with an embedding vector. The unit of deduplication and knowledge storage. |
| **Short** | A concise, ~1-minute-read generated article focused on a single concept. Produced by summarizing one or more related Chunks. The primary unit of learning consumption. |
| **Module** | A collection of related Shorts, formed by topic, concept, specific notes, user query, or knowledge graph clustering. Dynamically updated as Shorts change. |
| **Knowledge Graph (KG)** | A directed graph where nodes are Shorts/Concepts and edges represent relationships (prerequisite, related, deeper, broader, part-of). The backbone of navigation and adaptive pathing. |
| **Learning Path / Roadmap** | A personalized, dynamic sequence of Shorts for a user, computed by the recommendation engine and adjusted after every interaction. |
| **User Profile / Learner Model** | A comprehensive model of the user's knowledge state, interests, strengths, weaknesses, memory patterns, and interaction history. |
| **Exploration Prompts** | AI-generated follow-up questions or related topic suggestions attached to each Short, driving deeper learning. |
| **Familiarity Score** | A per-topic numeric estimate of how well the user knows a topic, inferred from interaction speed, frequency, and quiz performance. |
| **MMR (Maximal Marginal Relevance)** | A retrieval diversification technique that re-ranks results by balancing relevance to the query against redundancy with already-selected items. Controlled by a λ parameter (e.g., λ ≈ 0.7). |
| **Hybrid Retrieval** | A retrieval strategy combining dense vector similarity search with sparse keyword matching (BM25) to improve both recall and precision. |
| **Cross-Encoder Reranking** | A two-stage retrieval refinement where a cross-encoder model (e.g., BGE-Reranker) re-scores candidate results by jointly encoding query and document for higher-fidelity relevance ranking. |
| **Concept Inventory** | A pre-generation planning step where the system identifies all distinct concepts in retrieved context, enabling coverage-aware and non-redundant content generation. |
| **Canonicalization** | Normalizing text (lowercasing, whitespace collapsing, Unicode normalization, boilerplate stripping) before hashing to ensure deterministic duplicate detection despite surface-level formatting differences. |
| **Soft Deduplication** | Reducing the influence of duplicate or near-duplicate content (via downweighting, capping retrieval contribution) rather than hard-deleting it. Preserves source diversity and minority viewpoints while controlling redundancy. |
| **Context Compression** | A multi-stage pipeline (quality filtering → redundancy pruning → relevance scoring → token budgeting) that reduces retrieved context to maximize information density within the LLM's context window before generation. |
| **Query Expansion** | Lightweight augmentation of a user query with synonyms, related terms, or vocabulary from the knowledge base to improve retrieval recall without introducing semantic drift. |

---

## 3. Functional Requirements

### 3.1 Media Ingestion & Content Capture

| ID | Requirement |
|----|-------------|
| MI-01 | The system shall accept media shared from external apps (e.g., LinkedIn, YouTube, Twitter, browsers) via the OS share sheet / share intent. |
| MI-02 | The system shall allow users to manually upload media files (text, images, audio, video, documents such as PDF/DOCX). |
| MI-03 | The system shall allow users to enter or paste text directly as a note. |
| MI-04 | The system shall allow users to provide a URL, fetch the content from that URL, and process it as a note. |
| MI-05 | The system shall support RSS feed URLs as persistent sources, polling them at configurable intervals for new content. |
| MI-06 | The system shall support newsletter ingestion by parsing redirected email content or dedicated newsletter APIs. |
| MI-07 | The system shall support subscription to clubs, groups, or social media feeds as content sources. |
| MI-08 | The system shall support drag-and-drop file upload with multiple format support. |
| MI-09 | The system shall validate URL formats and source availability before adding them as persistent sources. |
| MI-10 | The system shall store raw notes in the Firestore `notes` collection with metadata (type, user ID, timestamps, source). |
| MI-11 | The system shall accept notes containing mixed media types (e.g., text + images in a single note). |
| MI-12 | The system shall capture Twitter/X threads with threading structure preservation. |
| MI-13 | **Source-Level Auto-Summary**: Upon successful ingestion of a new source (note, URL, file, RSS article), the system shall automatically generate: (a) a concise source summary, (b) a list of key topics/concepts covered, and (c) 3–5 suggested exploration questions. These shall be displayed to the user on the source detail view and used to seed the concept inventory and exploration prompts. |

### 3.2 Content Processing Pipeline

| ID | Requirement |
|----|-------------|
| CP-01 | Each media type shall be processed by a dedicated, generalized processor: TEXT (direct), IMAGE (Gemini Vision OCR + description), AUDIO (Speech-to-Text transcription), LINK (HTML parsing + content extraction via BeautifulSoup + Gemini), VIDEO (frame extraction + audio transcription), FILE (document parsing). |
| CP-02 | All extracted content shall be consolidated into a clean, unified text document with metadata for downstream processing. |
| CP-03 | Extracted text shall be split into semantically coherent chunks using a hierarchical chunking strategy: (1) split at structural boundaries first (headings, subheadings, explicit section breaks), (2) if no structural cues exist, split at paragraph boundaries, (3) if paragraphs exceed token budget, apply semantic change-point detection (sliding-window embedding cosine distance) to find topic shift boundaries, (4) as a final fallback, split at sentence boundaries within a token budget (~1000 words per chunk, ~200-word overlap). Chunk boundaries shall never split inside code blocks, mathematical formulas, named entities, or table rows. |
| CP-04 | For each chunk, the system shall generate a high-quality vector embedding using Gemini/Google GenAI (`models/embedding-001`). |
| CP-04a | The system shall validate chunk semantic coherence after splitting by: (a) computing intra-chunk embedding variance across sentence-level embeddings — high variance indicates topic drift, (b) applying sliding-window cosine change-point detection to locate internal topic boundaries, (c) optionally using a cross-encoder coherence model for high-value content. Chunks with poor coherence (variance above threshold) shall be recursively re-split at the detected change points until each sub-chunk is topically coherent. |
| CP-04b | **Chunk Embedding Metadata**: Each chunk embedding stored in the vector database shall include positional and provenance metadata: source_id, section_title, page/paragraph offset, token span, chunk quality/confidence score, and creation timestamp. This metadata enables accurate citation linking, source-level cascading deletions, and retrieval weighting. |
| CP-05 | The system shall implement a multi-stage deduplication pipeline for incoming chunks, executed in order: |
| CP-05a | **Stage 1 — Exact Deduplication**: Compute a content hash (SHA-256) of canonicalized chunk text. Chunks with identical hashes to existing chunks are discarded immediately. Canonicalization includes: Unicode NFC normalization, whitespace collapsing, lowercasing, and boilerplate stripping. |
| CP-05b | **Stage 2 — Near-Duplicate Detection**: Apply shingling with MinHash/LSH or SimHash to detect syntactically near-identical chunks (Jaccard similarity ≥ 0.9 or Hamming distance ≤ 3). Near-duplicates are flagged for merge or discard. |
| CP-05c | **Stage 3 — Semantic Deduplication**: Query the ChromaDB vector store with the chunk embedding (user-scoped). Chunks with cosine similarity ≥ 0.85 to existing chunks are flagged as semantic duplicates. A cross-encoder or NLI model may optionally verify borderline cases (0.80–0.90 range). |
| CP-05d | **Stage 4 — Cross-Modal Deduplication**: When content is ingested from different media types (e.g., audio transcript + PDF text, video + article covering the same topic), the system shall detect semantic duplicates across modalities by comparing embeddings in a shared semantic space. Cross-modal duplicates shall be flagged and handled identically to same-modality semantic duplicates. |
| CP-06 | Only novel chunks (passing all deduplication stages) shall be inserted; duplicate chunks shall be discarded with a logged deduplication decision (stage, method, matched chunk ID, similarity score). When semantically duplicate chunks from different sources are detected, their citations shall be merged into one canonical chunk entry, preserving all source attributions (citation merging). |
| CP-07 | For novel chunks, the system shall invoke Gemini to generate a concise, one-paragraph summary covering the chunk's information — this becomes a Short. |
| CP-08 | Each generated summary shall be checked for uniqueness against existing Shorts via semantic similarity before creation. |
| CP-09 | The system shall extract and tag topics from each Short using keyword matching or pre-trained classifiers. |
| CP-10 | The system shall assess the difficulty/complexity of each Short on a 0.0–1.0 scale. |
| CP-11 | The system shall generate 5–10 follow-up exploration questions or related topic suggestions for each Short. |
| CP-12 | The entire processing pipeline (extraction → chunking → dedup → embedding → article generation) shall complete within 10 seconds for typical single-note inputs. |
| CP-13 | The system shall use Named Entity Recognition (NER) to identify and tag important entities for knowledge graph integration. |
| CP-14 | The system shall handle malformed or partial content gracefully, logging warnings and skipping unprocessable segments. |
| CP-15 | Summarization shall minimize hallucination via factuality-aware models, retrieval grounding, and/or post-generation consistency checks. |
| CP-16 | **Conflict Detection**: When deduplication or merging identifies overlapping content that contains conflicting facts or claims, the system shall preserve both versions with source attribution rather than silently discarding one. Conflicting facts shall be surfaced to the user or marked in the Short. |
| CP-17 | **Anti-Density Controls**: The system shall enforce per-source quotas and cluster-aware sampling during retrieval and content generation to prevent any single source from dominating the user's knowledge base. Inverse-frequency weighting shall down-rank over-represented topics. |
| CP-18 | **Deduplication Auditability**: Every deduplication decision shall be logged with: stage (exact/near-duplicate/semantic), method used, matched chunk reference, similarity score, and outcome (discard/merge/keep). Logs shall be queryable for debugging and quality assessment. |
| CP-19 | **Streaming Deduplication**: For real-time ingestion pipelines (e.g., RSS polling, share intent bursts), the system shall use probabilistic data structures (Bloom filters or Count-Min Sketch) for fast approximate duplicate screening before the full multi-stage pipeline. |
| CP-20 | **Content Canonicalization**: Before any hashing or comparison, text shall be canonicalized: Unicode NFC normalization, whitespace/newline collapsing, lowercasing, punctuation normalization, and removal of boilerplate (headers, footers, navigation text). |
| CP-21 | **Soft Deduplication Strategy**: The system shall prefer soft deduplication (downweighting retrieval influence, capping source contribution) over hard deletion for near-duplicates from different sources. This preserves source diversity and minority viewpoints while reducing redundancy. Hard deletion shall apply only to exact duplicates (Stage 1). Near-duplicates and semantic duplicates shall be kept but linked to a canonical representative, with retrieval preferring the canonical chunk. |
| CP-22 | **Concept Discovery Pipeline**: The system shall identify and maintain a concept inventory across the knowledge base via: (a) embedding-based clustering of chunks using community detection algorithms (e.g., Leiden, Louvain, or HDBSCAN), (b) LLM-assisted concept labeling per cluster, (c) importance scoring per concept based on number of contributing sources, structural prominence (heading-level), and cross-reference frequency. The concept inventory shall update incrementally as new Shorts are added or removed. |
| CP-23 | **Multiple Index Types**: The system shall maintain complementary indices for the knowledge base: (a) a **vector index** (FAISS/ChromaDB) for semantic similarity search, (b) a **lexical/keyword index** (BM25-style) for exact term, acronym, and entity matching, (c) a **structural/provenance index** mapping source → section → chunk hierarchy for citation resolution and cascading deletions, (d) a **concept/topic cluster index** linking concepts to their constituent chunks for coverage-aware content generation, and (e) an **entity index** mapping named entities (from NER in CP-13) to their containing chunks for entity-based retrieval. |
| CP-24 | **Generation-Time Deduplication**: During LLM text generation (Shorts, summaries, flashcards), the system shall enforce coverage constraints and fact canonicalization — preventing the LLM from repeating the same information across different parts of the output. This includes structured answer-plan prompting, coverage penalty instructions, and post-generation deduplication of factual claims. |

### 3.3 Shorts Management

| ID | Requirement |
|----|-------------|
| SM-01 | Each Short shall contain: title, content (Markdown), summary, topics, tags, difficulty, citations (source note IDs and chunk IDs), exploration prompts, embedding vector, timestamps, engagement metrics. |
| SM-02 | Shorts shall be readable in approximately 1 minute (~150–250 words), focusing on a single concept in depth without overwhelming the user. |
| SM-03 | Existing Shorts shall be automatically updated when their source note/media is edited — the system re-processes the note and regenerates affected Shorts. |
| SM-04 | Shorts shall be automatically merged when the system detects that two or more Shorts cover substantially the same concept (semantic similarity above threshold). |
| SM-05 | Shorts shall be automatically deleted when their source note is deleted and no other notes contribute to the same chunks. |
| SM-06 | Each Short shall maintain prerequisite references (IDs of Shorts that should be read before this one). |
| SM-07 | Each Short shall maintain related article references with relationship types (deeper, broader, next, similar) and relevance scores. |
| SM-08 | Shorts shall track engagement metrics: view count, completion count, skip count, save count, share count, average time spent, engagement score. |
| SM-09 | Shorts shall support Markdown rendering with rich content (text, images, code blocks, links). |
| SM-10 | The system shall support article versioning — tracking changes over time when Shorts are updated. |

### 3.4 Module Management

| ID | Requirement |
|----|-------------|
| MO-01 | Modules shall be collections of related Shorts, grouping them for structured learning. |
| MO-02 | Modules can be formed automatically based on: topic/concept clustering, knowledge graph communities, or specific source notes. |
| MO-03 | Modules can be formed manually by user request: selecting specific Shorts, providing a query, or defining a concept/topic. |
| MO-04 | Modules shall be automatically updated when new Shorts are generated that belong to the module's topic/concept scope. |
| MO-05 | Modules shall be automatically updated when existing Shorts within them are updated, merged, or deleted. |
| MO-06 | Users shall be able to delete modules (without deleting the constituent Shorts). |
| MO-07 | Modules shall have metadata: name, description, topics covered, difficulty progression, estimated completion time, creation method (auto/manual). |
| MO-08 | Modules shall track progress: total Shorts, completed Shorts, current position, estimated remaining time. |
| MO-09 | Modules can contain adaptive rules that modify the sequence of Shorts based on user performance within the module. |

### 3.5 Knowledge Graph & Navigation

| ID | Requirement |
|----|-------------|
| KG-01 | The system shall organize all Shorts and Concepts in a Knowledge Graph, with nodes representing Shorts/Concepts and edges representing relationships (prerequisite, related, part-of, deeper, broader, example-of). |
| KG-02 | The Knowledge Graph shall support hierarchical levels: Level 1 (broad topic summaries), Level 2 (detailed subtopics), Level 3+ (in-depth/niche content). |
| KG-03 | From any Short, the user shall be able to **dive deeper** — the system prioritizes sub-topic Shorts, deferring unrelated ones. |
| KG-04 | From any Short, the user shall be able to **go up a level** (one or more levels) — moving to broader topic coverage. |
| KG-05 | From any Short, the user shall be able to **go to next** — proceeding to the next recommended Short in the current roadmap. |
| KG-06 | From any Short, the user shall be able to navigate to **related Shorts** — laterally exploring connected concepts. |
| KG-07 | The user shall be able to **switch topics midway** — the system tracks progress and ensures all Shorts are eventually presented. |
| KG-08 | No matter what path the user follows through the Knowledge Graph, the system shall ensure all Shorts are eventually covered (universal traversal guarantee). |
| KG-09 | Completing a prerequisite Short can **automatically suggest or mark completion** of dependent Shorts (e.g., "Introduction to AI" completing "AI Basics"). |
| KG-10 | The Knowledge Graph shall be updated in real-time as new Shorts are added, updated, merged, or deleted. |
| KG-11 | Navigation options (dive deeper, go up, related, next) shall be dynamically generated based on the current Short's position in the graph and available unread connections. |
| KG-12 | When the user dives deeper, the system shall use a stack/queue mechanism to remember where the user left off and resume the previous sequence after the deeper topic is exhausted. |
| KG-13 | The system shall support graph visualization so users can see the web of interconnected Shorts and their learning progress within it. |
| KG-14 | Multiple navigation paths shall be available at each node — the system orders them by recommendation score, but the user can choose freely. |
| KG-15 | The graph shall use a directed acyclic graph (DAG) structure for prerequisite relationships, while allowing cyclic relationships for "related" and "similar" edges. |
| KG-16 | **Temporal Knowledge Graph**: The system shall track concept evolution over time — recording when concepts were added, updated, or superseded. This enables the system to surface how a topic has evolved across ingested sources and to prioritize the most current understanding. |
| KG-17 | **Soft/Dynamic Edges**: In addition to explicit prerequisite/related edges, the system shall maintain dynamic similarity-based edges (k-NN by embedding distance, co-citation, shared entity links) that update automatically as new Shorts are added. These soft edges complement rigid structural edges for navigation and recommendation. |

### 3.6 Adaptive Learning & Personalization

| ID | Requirement |
|----|-------------|
| AL-01 | After every user interaction (read, skip, save, navigate), the system shall recalculate and adjust the entire subsequent learning roadmap. |
| AL-02 | The recommendation engine shall score unread Shorts using multi-factor scoring: semantic relevance to user interests (40%), capability alignment with user level (30%), novelty/recency (30%). Weights shall be configurable. |
| AL-03 | The system shall use probabilistic estimation (Markov chains, contextual bandits, or RL) to predict optimal next Shorts, analogous to how LLMs predict next tokens based on current state. |
| AL-04 | For topics where the user demonstrates high familiarity (frequent, quick "done" actions), the system shall group related Shorts into a single summary or skip them entirely — reducing cognitive load. |
| AL-05 | For topics where the user demonstrates low familiarity (frequent skips, slow interactions), the system shall present full, detailed Shorts with additional context. |
| AL-06 | The system shall incorporate temporal diversity constraints — recommending varied content across topics rather than exclusively deep-diving into one area (unless the user chooses to). |
| AL-07 | The system shall adjust Short difficulty based on demonstrated user comprehension — avoiding content that is too easy (boring) or too hard (frustrating). |
| AL-08 | The system shall support cold-start recommendations for new users using initial interest selection and content-based filtering. |
| AL-09 | The system shall implement Bayesian Knowledge Tracing (BKT) or equivalent to model per-concept mastery, tracking: prior knowledge probability, learning probability, slip probability, guess probability. |
| AL-10 | The system shall use reinforcement learning to optimize learning path selection over time: states = user knowledge, actions = Short recommendations, rewards = engagement + comprehension. |
| AL-11 | The system shall balance exploration (introducing new topics) with exploitation (deepening known interests) using contextual bandit algorithms. |
| AL-12 | The system shall adapt to contextual factors: time of day (morning vs. evening reading habits), session duration patterns, device type. |
| AL-13 | The roadmap shall adapt dynamically using graph-based models — Graph Neural Networks (GNNs) encoding the Knowledge Graph structure plus user state for policy training. |

### 3.7 User Profiling & Modeling

| ID | Requirement |
|----|-------------|
| UP-01 | The system shall maintain a comprehensive user profile including: interests/topics, educational level, learning goals, learning mode (visual/auditory/kinesthetic), strengths, weaknesses. |
| UP-02 | The system shall track per-topic familiarity scores, derived from interaction speed, frequency of marking done, quiz performance, and time spent. |
| UP-03 | The system shall infer what the user easily remembers vs. what they struggle with, based on quiz results and spaced repetition performance. |
| UP-04 | The system shall track user capabilities per knowledge domain: expertise level (0–100), confidence score, last updated timestamp. |
| UP-05 | The system shall track detailed interaction history: article interactions (type, timestamp, time spent, scroll depth, device), navigation patterns (from/to article, direction, timestamp). |
| UP-06 | The system shall maintain reading pattern analytics: average session duration, sessions per week, completion rate, return rate. |
| UP-07 | The system shall model the user's current knowledge state as an overlay on the Knowledge Graph — mapping which concepts are mastered, in progress, or unknown. |
| UP-08 | The user shall be able to explicitly set and modify their interests, learning goals, learning mode, and proficiency levels. |
| UP-09 | The system shall continuously refine the user profile based on ongoing interactions without requiring explicit user input. |
| UP-10 | The user profile shall support preference for content depth: brief summaries vs. detailed explanations. |

### 3.8 Retention & Assessment

| ID | Requirement |
|----|-------------|
| RA-01 | The system shall implement spaced repetition scheduling — resurfacing previously-read Shorts at optimal intervals to reinforce retention. |
| RA-02 | The system shall generate quizzes on Shorts the user has marked as completed — testing comprehension and recall. |
| RA-03 | Quiz results shall feed back into the user profile: updating familiarity scores, identifying weak areas, and adjusting the learning roadmap accordingly. |
| RA-04 | The system shall track what the user easily remembers vs. what they forget, and schedule more frequent reviews for weak areas. |
| RA-05 | The system shall support active recall mechanisms — prompting the user with questions before showing the answer or related Short. |
| RA-06 | Retention metrics shall be visible to the user: memory strength per topic, upcoming reviews, review history. |
| RA-07 | The system shall provide adaptive quiz difficulty — easier questions for low-confidence concepts, harder questions for high-confidence ones. |
| RA-08 | Quiz types shall include: multiple choice, true/false, fill-in-the-blank, open-ended (AI-graded), and short-answer. |
| RA-09 | **Concept Inventory Planning**: Before generating quizzes or flashcards for a Module or topic, the system shall build a concept inventory by: (a) clustering relevant chunk embeddings via community detection (Leiden/Louvain/HDBSCAN), (b) labeling each cluster with a concept name using lightweight LLM inference, (c) scoring concept importance based on number of contributing sources, structural prominence, and cross-reference frequency. This ensures coverage-aware generation that tests across all relevant concepts without redundancy. |
| RA-10 | **Targeted Concept Retrieval for Assessment**: Quiz and flashcard generation shall retrieve context per-concept from the knowledge base (rather than a single bulk retrieval), ensuring each question is grounded in the most relevant source material for that specific concept. |
| RA-11 | **Flashcard/Quiz Output Deduplication**: After generating a set of flashcards or quiz questions, the system shall deduplicate the output — detecting and merging Q&A pairs that test the same concept with substantially overlapping wording (semantic similarity above threshold). This prevents the user from seeing redundant study cards, especially when multiple sources cover the same topic. |
| RA-12 | **Assessment Conflict Handling**: When source content contains conflicting facts or interpretations, flashcard and quiz generation shall create comparison-style items that surface both viewpoints with source attribution, rather than silently choosing one interpretation. |

### 3.9 RAG / Knowledge Query

| ID | Requirement |
|----|-------------|
| RQ-01 | The user shall be able to query their personal knowledge base using natural language from within the app. |
| RQ-02 | The system shall use Retrieval-Augmented Generation (RAG) with **hybrid retrieval**: combining dense vector similarity search (ChromaDB, user-scoped) with sparse keyword matching (BM25/lexical index) to maximize both semantic recall and keyword precision. Retrieval shall support **hierarchical granularity** — first identifying relevant sections/sources, then retrieving specific chunks within those sections — for queries requiring broad context. |
| RQ-03 | Answers shall include grounded citations — linking back to the source Shorts and Notes that informed the response. Each claim in the generated answer shall be attributable to a specific retrieved source passage. |
| RQ-04 | The union of auto-generated exploration questions and user-asked questions shall be usable as research prompts — the system can investigate them further and generate new Shorts if sufficient source material exists. |
| RQ-05 | The system shall support conversational follow-up queries, maintaining context within a query session. |
| RQ-06 | RAG queries shall respect user data isolation — only querying the user's own knowledge base. |
| RQ-07 | **Cross-Encoder Reranking**: After initial retrieval, the system shall apply a cross-encoder reranking model (e.g., BGE-Reranker) to re-score the top-k retrieved chunks by jointly encoding query and chunk for higher-fidelity relevance ordering. |
| RQ-08 | **MMR Diversification**: Retrieved results shall be diversified using Maximal Marginal Relevance (MMR, λ ≈ 0.7) to balance relevance against redundancy — ensuring the context window presented to the LLM covers diverse aspects of the query rather than repeating similar passages. |
| RQ-09 | **Context Compression Pipeline**: Before passing retrieved context to the LLM for generation, the system shall compress it through a staged pipeline: (a) **quality filtering** — drop chunks with low OCR/transcription confidence or below a relevance threshold, (b) **sentence-level redundancy pruning** — embed individual sentences within retrieved chunks, cluster at cosine ≥ 0.92, and keep one representative per cluster, (c) **relevance scoring** — rank remaining sentences by combined relevance-to-query and novelty scores, retaining the highest-contribution sentences, (d) **token budget management** — remove the lowest-contribution sentences until the context fits within the LLM's available context window (total window minus safety margin minus expected output length). |
| RQ-10 | **Audio Summary Generation**: The system shall support generating audio overviews/podcast-style summaries from a set of Shorts or a Module, using LLM synthesis followed by text-to-speech — distinct from per-Short TTS playback. |
| RQ-11 | **Query Expansion**: The system shall perform lightweight query expansion — injecting synonyms, related terms, and vocabulary drawn from the user's knowledge base — to improve retrieval recall. Expansion shall avoid full LLM rewriting to prevent semantic drift and maintain trust. Both the original query and expanded terms shall be used in hybrid retrieval. |
| RQ-12 | **Task-Specific Retrieval Orchestration**: Different output tasks (Q&A, flashcard generation, summary, audio overview, mind map) shall use task-appropriate retrieval parameters — varying MMR λ (higher for Q&A precision, lower for study guide coverage), per-source chunk quotas, compression aggressiveness, and prompt templates. This shall be configuration-driven (parameterized pipeline profiles), not hard-coded branching. |
| RQ-13 | **Mind Map / Outline Generation**: The system shall support generating structured mind maps and hierarchical outlines from a set of Shorts, a Module, or a user-specified topic scope. These are generated by extracting concepts from relevant chunks, identifying inter-concept relationships (prerequisite, related, part-of), and presenting them as a navigable hierarchical visual structure. |

### 3.10 Search & Discovery

| ID | Requirement |
|----|-------------|
| SD-01 | The app shall provide a search bar for finding Shorts by keyword, topic, or title with fuzzy matching. |
| SD-02 | Search results shall be filterable by: topic, difficulty level, read/unread status, date, source, module. |
| SD-03 | Search results shall be sortable by: relevance, recency, difficulty, popularity. |
| SD-04 | The system shall support semantic search — finding conceptually related Shorts even if exact keywords don't match. |
| SD-05 | The system shall surface trending or popular Shorts based on aggregate engagement metrics. |
| SD-06 | The system shall suggest related topics and Shorts as the user types a search query. |

### 3.11 User Interactions & Engagement

| ID | Requirement |
|----|-------------|
| UI-01 | The user shall be able to **mark a Short as completed/done** — signaling comprehension and updating the knowledge profile. |
| UI-02 | The user shall be able to **skip a Short** — it is deferred for later and the system infers reduced interest or readiness. |
| UI-03 | The user shall be able to **save/bookmark a Short** — adding it to a personal collection for later reference. |
| UI-04 | The user shall be able to **share a Short** — via system share sheet to social media, email, or messaging apps. |
| UI-05 | The user shall be able to **dive deeper** — navigating to more detailed Shorts within the current topic. |
| UI-06 | The user shall be able to **go up a level** — navigating to broader topic Shorts. |
| UI-07 | The system shall track time spent on each Short (for engagement and comprehension inference). |
| UI-08 | The system shall track scroll depth on each Short. |
| UI-09 | Every interaction shall trigger a roadmap recalculation and recommendation engine refresh. |
| UI-10 | The user shall be able to provide explicit feedback on a Short (e.g., "too easy", "too hard", "not relevant"). |
| UI-11 | Swipe gestures shall be supported for navigation (e.g., swipe left for next, swipe up for deeper). |
| UI-12 | Haptic feedback and visual indicators shall accompany interaction actions (e.g., marking as done). |

### 3.12 Social & Sharing

| ID | Requirement |
|----|-------------|
| SS-01 | Users shall be able to share Shorts externally via the system share sheet (social media, email, messaging). |
| SS-02 | Users shall be able to receive shared content from other apps (via share intent) and have it ingested as a new note. |
| SS-03 | Shared content shall be auto-processed into Shorts if the user is authenticated. |
| SS-04 | Deep links shall be supported — enabling users to share links to specific Shorts that open directly in the app. |

### 3.13 Notifications

| ID | Requirement |
|----|-------------|
| NO-01 | The system shall send push notifications for significant events: new Shorts from monitored sources, spaced repetition review reminders, streak maintenance reminders. |
| NO-02 | Notification preferences shall be configurable: per-topic, per-source, frequency, quiet hours. |
| NO-03 | In-app notifications shall provide subtle alerts for real-time content updates. |
| NO-04 | Notifications shall support deep linking — tapping opens the relevant Short or screen. |
| NO-05 | Learning streak notifications shall encourage daily engagement. |

### 3.14 Settings & Preferences

| ID | Requirement |
|----|-------------|
| SP-01 | Theme: Light mode, Dark mode, System default. |
| SP-02 | Font size adjustment: Small, Medium, Large (applied to Short content). |
| SP-03 | Language preference (prepared for internationalization). |
| SP-04 | Manage interests and topics from settings. |
| SP-05 | Manage content sources (add, edit, remove, pause URLs/RSS feeds). |
| SP-06 | Notification preferences (enable/disable, per-topic, frequency). |
| SP-07 | Text-to-speech toggle and voice selection for listening to Shorts. |
| SP-08 | Data export/import (JSON, CSV formats for portability). |
| SP-09 | Clear cache / manage storage. |
| SP-10 | Account deletion and data erasure. |
| SP-11 | Learning mode preference (visual, auditory, kinesthetic — influences content presentation). |

### 3.15 Authentication & Profile

| ID | Requirement |
|----|-------------|
| AP-01 | Email/password authentication with password reset functionality. |
| AP-02 | Google Sign-In integration. |
| AP-03 | User profile management: display name, photo, email. |
| AP-04 | Profile customization: learning mode, strengths, weaknesses, interests, goals. |
| AP-05 | Session management via persistent tokens (SharedPreferences). |
| AP-06 | Guest/anonymous browsing with limited features and optional upgrade to full account. |
| AP-07 | Guest data sync — prompting guests to create an account and migrating their local data. |

### 3.16 Onboarding

| ID | Requirement |
|----|-------------|
| ON-01 | First-launch onboarding flow with feature showcase explaining key concepts (Shorts, Modules, Knowledge Graph, navigation). |
| ON-02 | Interest/topic selection screen during onboarding (with searchable list). |
| ON-03 | Initial source setup — option to add URLs, select pre-defined sources, or skip. |
| ON-04 | Learning goal selection (e.g., "learn AI", "stay updated on tech"). |
| ON-05 | Proficiency self-assessment for selected topics (beginner/intermediate/advanced). |
| ON-06 | Onboarding completion triggers initial content fetch and roadmap generation. |

### 3.17 Offline & Sync

| ID | Requirement |
|----|-------------|
| OS-01 | The app shall support offline reading — caching Shorts locally for access without internet. |
| OS-02 | Firestore persistence shall be enabled with unlimited cache size for offline access. |
| OS-03 | The app shall monitor network connectivity and display a connectivity banner/indicator. |
| OS-04 | User interactions performed offline shall sync automatically when the device reconnects. |
| OS-05 | The app shall provide cross-device synchronization — progress, bookmarks, and settings sync across devices. |
| OS-06 | Conflict resolution shall be handled gracefully when the same data is modified on multiple devices. |

### 3.18 Analytics & Progress Tracking

| ID | Requirement |
|----|-------------|
| AT-01 | The app shall display learning streaks (current streak, best streak, last active date). |
| AT-02 | The app shall show total Shorts completed, topics covered, and time invested. |
| AT-03 | The app shall display per-topic expertise levels with progress visualization. |
| AT-04 | The app shall show reading history with timestamps and topics. |
| AT-05 | The app shall provide a progress dashboard with charts/graphs for: topic distribution, completion rate, engagement over time, difficulty progression. |
| AT-06 | The app shall show Knowledge Graph progress — a visual map highlighting which nodes (Shorts/Concepts) are completed, in progress, or unread. |
| AT-07 | The app shall track and display learning velocity — how quickly the user is progressing through topics. |
| AT-08 | The app shall provide gamification elements: badges, milestones, achievements for reaching learning goals. |

### 3.19 Content Source Management

| ID | Requirement |
|----|-------------|
| CS-01 | Users shall be able to add, edit, pause, resume, and delete content sources (URLs, RSS feeds, newsletters, subscriptions). |
| CS-02 | Each source shall have configuration: URL, fetch frequency, default topics/tags, content filters, field mappings. |
| CS-03 | The system shall display source health/status: active, paused, error (with error messages). |
| CS-04 | The system shall show source statistics: total articles fetched, last fetch time, success rate. |
| CS-05 | The system shall validate sources on addition — checking URL availability, RSS/API format, and content accessibility. |
| CS-06 | The system shall continuously monitor active sources at configurable intervals, fetching and processing new content. |
| CS-07 | The system shall support predefined source catalogs — curated lists of popular educational sources the user can subscribe to with one tap. |

### 3.20 Lifecycle Management

| ID | Requirement |
|----|-------------|
| LM-01 | On note edit: the system shall automatically re-process the note, regenerate affected chunks, update embeddings in ChromaDB, and regenerate affected Shorts. |
| LM-02 | On note deletion: the system shall remove associated chunks from ChromaDB, delete Shorts that rely solely on the deleted note's chunks, and refresh recommendations. |
| LM-03 | Media/source deletion shall cascade — removing all derived Shorts and chunks while preserving Shorts that have been merged with content from other sources. |
| LM-04 | The system shall guarantee no residual or duplicate knowledge remains across the vector store or Shorts collection after any lifecycle event. |
| LM-05 | On Short merge: the system shall combine content, update citations, preserve user interactions (completion status), and update Knowledge Graph edges. |
| LM-06 | On Module update (Short added/removed/merged): the system shall recalculate module metadata (topic coverage, difficulty progression, estimated time). |
| LM-07 | All lifecycle operations shall update the recommendation engine — triggering re-scoring and roadmap adjustment for affected users. |
| LM-08 | Processing tasks shall be tracked with status lifecycle (pending → processing → completed/failed) with error messages for failures. |

### 3.21 Browser Extension Companion

| ID | Requirement |
|----|-------------|
| BE-01 | A cross-browser extension (Chrome, Firefox, Safari, Edge) shall enable users to capture web content and send it to Geeky for processing. |
| BE-02 | The extension shall support: saving entire pages, saving selected text with context, extracting main article content. |
| BE-03 | The extension shall support highlighting text on web pages with persistence and multi-device sync. Users shall be able to create, edit, and remove highlights. The extension shall provide a highlight management dashboard for reviewing all highlights across pages. |
| BE-04 | The extension shall provide a quick-save button and context menu (right-click) integration. |
| BE-05 | The extension shall sync captured content with the user's Geeky account via Firebase. |
| BE-06 | The extension shall support offline capture with sync when online. |
| BE-07 | **Template & Metadata Extraction**: The extension shall support custom capture templates with automatic metadata extraction — Schema.org structured data, OpenGraph tags, and URL-pattern-based template triggers. Users shall be able to define custom templates for recurring source patterns. |
| BE-08 | **AI-Powered Auto-Highlighting**: The extension shall optionally highlight key passages on a page using AI analysis, identifying the most informative or novel content relative to the user's existing knowledge base. |
| BE-09 | **Extension Performance**: The extension shall not exceed 50MB storage footprint, shall support 10,000+ saved items, and shall deliver search results within < 200ms. |

---

## 4. Non-Functional Requirements

### 4.1 Performance

| ID | Requirement |
|----|-------------|
| PF-01 | API response time: < 500ms for simple queries (article listing, user profile). |
| PF-02 | Content extraction/processing: < 5 seconds per typical single note. |
| PF-03 | Full pipeline (note → Shorts): < 10 seconds for a standard note. |
| PF-04 | Vector similarity search: < 200ms for 10 results. |
| PF-05 | Search operations: < 200ms response time. |
| PF-06 | Mobile app: smooth 60fps animations and scrolling. |
| PF-07 | Lazy loading for Short lists and content feeds. |
| PF-08 | Efficient image loading via caching (CachedNetworkImage). |
| PF-09 | Recommendation recalculation: < 2 seconds after user interaction. |

### 4.2 Scalability

| ID | Requirement |
|----|-------------|
| SC-01 | Support 10,000+ saved items (notes + Shorts) per user. |
| SC-02 | Horizontal scaling via Cloud Run auto-scaling (scale to zero when idle). |
| SC-03 | Per-user limits enforced: 1000 notes, 500 articles (configurable for paid tiers). |
| SC-04 | Concurrent processing limited to 10 notes via semaphore. |
| SC-05 | ChromaDB scalable independently from the main API. |
| SC-06 | Knowledge Graph operations shall handle 10,000+ nodes and 50,000+ edges per user without degradation. |

### 4.3 Reliability & Availability

| ID | Requirement |
|----|-------------|
| RE-01 | Offline-first architecture: core reading and navigation available without internet. |
| RE-02 | Graceful degradation: if ChromaDB is unreachable, fall back to keyword search; if Speech-to-Text is unavailable, skip audio processing with warning; if Gemini rate-limited, queue with exponential backoff. |
| RE-03 | Automatic retry with exponential backoff for transient failures. |
| RE-04 | Failed processing tasks logged with error details for debugging. |
| RE-05 | Data consistency guaranteed across Firestore, ChromaDB, and Knowledge Graph after any operation. |
| RE-06 | Background sync shall recover from interruptions and resume without data loss. |

### 4.4 Security

| ID | Requirement |
|----|-------------|
| SE-01 | All API communication over HTTPS/TLS. |
| SE-02 | Firebase Authentication for user identity (email/password, Google Sign-In). |
| SE-03 | User-scoped data isolation: all ChromaDB queries filtered by `user_id`; Firestore rules enforce `request.auth.uid == resource.data.userId`. |
| SE-04 | API keys stored in environment variables, never exposed in client responses. |
| SE-05 | Rate limiting per user: max 1000 API calls/day (configurable). |
| SE-06 | Input validation and HTML sanitization (Bleach) on all user-provided content. |
| SE-07 | CORS restricted to allowed domains in production. |

### 4.5 Privacy & Compliance

| ID | Requirement |
|----|-------------|
| PR-01 | Per-user data isolation — content from one user is never accessible to another. |
| PR-02 | GDPR compliance: data portability (export), right to erasure (account deletion clears all data), consent management. |
| PR-03 | Data retention policies shall be configurable. |
| PR-04 | Analytics data shall be anonymized. |
| PR-05 | User data shall be exportable in standard formats (JSON, CSV). |
| PR-06 | Transparent AI: the system shall provide explanations for why a Short was recommended (reason + explanation text). |

### 4.6 Cost Optimization

| ID | Requirement |
|----|-------------|
| CO-01 | Operate on Google Cloud's free/Spark plan: Firestore (50K reads, 20K writes/day), Cloud Run (180K vCPU-sec/month), Cloud Storage (5GB). |
| CO-02 | Scale-to-zero serverless architecture — no idle costs. |
| CO-03 | Batch processing to reduce Cloud Function invocations. |
| CO-04 | Efficient Firestore queries with proper indexing. |
| CO-05 | Caching for repeated Gemini embedding/inference queries. |

### 4.7 Maintainability & Extensibility

| ID | Requirement |
|----|-------------|
| MA-01 | Modular architecture: media processors, recommendation engine, Knowledge Graph, and UI are independently deployable and testable. |
| MA-02 | Separation of concerns: routes → services → data layer (no business logic in routes). |
| MA-03 | All I/O operations use async/await for non-blocking execution. |
| MA-04 | Structured logging (JSON format) with correlation IDs for distributed tracing. |
| MA-05 | Comprehensive unit and integration tests with fixtures. |
| MA-06 | Feature flags for gradual rollout of new capabilities. |
| MA-07 | Adding a new media type processor shall require only creating a new processor class without modifying core logic. |

### 4.8 Accessibility

| ID | Requirement |
|----|-------------|
| AC-01 | Semantic labels for screen readers on all interactive elements. |
| AC-02 | High-contrast themes and adjustable text sizes. |
| AC-03 | Keyboard and gesture navigation support. |
| AC-04 | Text-to-speech support for all Short content. |
| AC-05 | Responsive design for phones, tablets, and web (LayoutBuilder, MediaQuery). |
| AC-06 | Support for portrait and landscape orientations. |

### 4.9 AI/ML Quality Metrics

| ID | Requirement |
|----|-------------|
| QM-01 | Summarization quality: generated Shorts shall achieve ROUGE-L ≥ 0.45 against source content, measured on a held-out evaluation set. |
| QM-02 | Deduplication precision: the multi-stage deduplication pipeline shall achieve cluster purity ≥ 0.85 — ensuring true duplicates are caught without discarding distinct content. |
| QM-03 | Recommendation relevance: the recommendation engine shall achieve Mean Reciprocal Rank (MRR) ≥ 0.35 — the relevant next Short should appear in the top 3 suggestions on average. |
| QM-04 | Knowledge Graph latency: graph query operations (traversal, neighbor lookup, path computation) shall complete in < 500ms for graphs with up to 10,000 nodes. |
| QM-05 | Embedding quality: semantic search recall@10 shall be ≥ 0.80 — at least 80% of relevant chunks appear in the top 10 results for a given query. |
| QM-06 | Deduplication recall: the pipeline shall catch ≥ 95% of true duplicates as measured on benchmark datasets (e.g., NEWS-COPY, C4 subsets). |

---

## 5. User Stories

### Media Ingestion

| # | User Story |
|---|-----------|
| US-01 | As a user, I want to share a YouTube video from the YouTube app to Geeky so that the video content is automatically transcribed and converted into learning Shorts. |
| US-02 | As a user, I want to share a LinkedIn post so that key insights are extracted and turned into a Short. |
| US-03 | As a user, I want to paste a URL and have Geeky fetch, summarize, and create Shorts from the web page content. |
| US-04 | As a user, I want to take a photo of my whiteboard notes and upload it so that text is extracted via OCR and Shorts are generated. |
| US-05 | As a user, I want to upload a PDF document so that its contents are parsed and turned into structured Shorts. |
| US-06 | As a user, I want to record a voice memo and have it transcribed into a note that generates Shorts. |
| US-07 | As a user, I want to type or paste text directly as a note for immediate processing into Shorts. |
| US-08 | As a user, I want to add an RSS feed URL as a persistent source so that new articles are automatically fetched and processed into Shorts. |
| US-09 | As a user, I want to subscribe to a newsletter so that incoming editions are automatically processed into Shorts. |

### Shorts Consumption & Navigation

| # | User Story |
|---|-----------|
| US-10 | As a user, I want to browse Shorts in a card-based feed so that I can swipe through concise learning content. |
| US-11 | As a user, I want to mark a Short as "done" so that the system knows I've learned this concept and adjusts my roadmap. |
| US-12 | As a user, I want to skip a Short so that it comes back later when I'm more ready for it. |
| US-13 | As a user, I want to save/bookmark a Short so that I can revisit it from my saved collection. |
| US-14 | As a user, I want to dive deeper into the current topic so that I see more detailed sub-topic Shorts before moving on. |
| US-15 | As a user, I want to go up a level so that I can see the broader context before continuing. |
| US-16 | As a user, I want to switch topics midway so that I can explore a different area and come back later. |
| US-17 | As a user, I want to see why a particular Short was recommended to me so that I understand the system's logic. |
| US-18 | As a user, I want the system to guarantee that I'll eventually cover all Shorts, regardless of what navigation path I take. |

### Modules

| # | User Story |
|---|-----------|
| US-19 | As a user, I want to see auto-generated Modules grouping related Shorts so that I can study topics in a structured way. |
| US-20 | As a user, I want to create a custom Module by selecting specific Shorts or specifying a query/topic. |
| US-21 | As a user, I want Modules to automatically update when new relevant Shorts are generated. |
| US-22 | As a user, I want to track my progress within a Module (X of Y completed). |
| US-23 | As a user, I want to delete a Module without losing the individual Shorts. |

### Adaptive Learning

| # | User Story |
|---|-----------|
| US-24 | As a user, I want the system to notice when I'm quickly marking Shorts as done and automatically skip or summarize related beginner content so that I'm not bored. |
| US-25 | As a user, I want the system to detect when I'm struggling with a topic and provide more foundational content before advancing. |
| US-26 | As a user, I want my learning roadmap to automatically update after every interaction. |
| US-27 | As a user, I want the system to balance variety — showing me Shorts across different topics rather than only one. |
| US-28 | As a user, I want to set my proficiency level for topics so the system starts at the right difficulty. |

### Retention & Assessment

| # | User Story |
|---|-----------|
| US-29 | As a user, I want to be quizzed on Shorts I've read so that I can test my retention and the system can track my comprehension. |
| US-30 | As a user, I want spaced repetition reminders — the system resurfaces old Shorts at optimal intervals for review. |
| US-31 | As a user, I want to see which topics I easily remember and which I struggle with. |
| US-32 | As a user, I want the quiz difficulty to adapt to my performance — harder questions for topics I know well, easier for new areas. |

### Knowledge Query

| # | User Story |
|---|-----------|
| US-33 | As a user, I want to ask a question in natural language and get an answer synthesized from my personal knowledge base (RAG). |
| US-34 | As a user, I want answers to include citations linking back to the source Shorts and Notes. |
| US-35 | As a user, I want the system to research unanswered questions and generate new Shorts if sufficient source material exists. |
| US-36 | As a user, I want follow-up exploration questions attached to each Short that I can tap to explore further. |

### Search & Discovery

| # | User Story |
|---|-----------|
| US-37 | As a user, I want to search my Shorts by keyword, topic, or title. |
| US-38 | As a user, I want to filter Shorts by topic, difficulty, read/unread status, and source. |
| US-39 | As a user, I want semantic search — finding related Shorts even when I don't use exact keywords. |

### Profile & Settings

| # | User Story |
|---|-----------|
| US-40 | As a user, I want to select my interests during onboarding so the system personalizes content from the start. |
| US-41 | As a user, I want to toggle dark mode and adjust font size. |
| US-42 | As a user, I want to manage my content sources — add, edit, pause, or remove them. |
| US-43 | As a user, I want to listen to Shorts via text-to-speech. |
| US-44 | As a user, I want to export my data (Shorts, Notes, progress) for portability. |
| US-45 | As a user, I want to delete my account and all associated data. |

### Progress & Analytics

| # | User Story |
|---|-----------|
| US-46 | As a user, I want to see my learning streak (current and best). |
| US-47 | As a user, I want to see how many Shorts I've completed, topics covered, and time invested. |
| US-48 | As a user, I want to visualize my progress on the Knowledge Graph — seeing which nodes are completed, in-progress, or unread. |
| US-49 | As a user, I want to earn badges and achievements for reaching milestones. |

### Offline & Sync

| # | User Story |
|---|-----------|
| US-50 | As a user, I want to read cached Shorts offline when I don't have internet. |
| US-51 | As a user, I want my progress and interactions to sync across all my devices. |
| US-52 | As a user, I want a visual indicator showing whether I'm online or offline. |

### Lifecycle

| # | User Story |
|---|-----------|
| US-53 | As a user, I want to edit a note and have all derived Shorts automatically update. |
| US-54 | As a user, I want to delete a note and have all orphaned Shorts and chunks cleaned up automatically. |
| US-55 | As a user, I want duplicate Shorts to be automatically merged so I never see redundant content. |

---

## 6. System Interactions & Automated Behaviors

These are system-level behaviors that happen automatically without direct user initiation:

| # | Automated Behavior | Trigger | Effect |
|---|--------------------|---------| -------|
| SYS-01 | **Note Processing Pipeline** | Note created/received via share intent or upload | Full pipeline: extraction → chunking → dedup → embedding → Short generation → KG update → recommendation refresh |
| SYS-02 | **Source Polling** | Configurable timer/cron (e.g., every 15 minutes) | RSS feeds and monitored URLs checked for new content; new content ingested as notes |
| SYS-03 | **Knowledge Graph Update** | New Short created, updated, merged, or deleted | Graph nodes and edges recalculated; hierarchy levels adjusted; navigation options regenerated |
| SYS-04 | **Roadmap Recalculation** | Any user interaction (read, skip, save, navigate, quiz) | Recommendation engine re-scores all unread Shorts; next-article pointer updated; learning path resequenced |
| SYS-05 | **Prerequisite Auto-Completion** | User completes a Short that is a prerequisite for others | System evaluates if dependent Shorts can be auto-marked as done or auto-skipped |
| SYS-06 | **Familiarity Score Update** | User marks Short as done (speed factored), quiz results, skip patterns | Per-topic familiarity scores recalculated; high familiarity triggers content summarization/skipping |
| SYS-07 | **Short Auto-Merge** | Semantic similarity between two Shorts exceeds threshold post-processing | Redundant Shorts merged into one; citations consolidated; KG edges updated; user progress preserved |
| SYS-08 | **Short Auto-Update** | Source note edited | Affected chunks re-processed; affected Shorts regenerated; KG and recommendations refreshed |
| SYS-09 | **Short Auto-Delete** | Source note deleted; all contributing chunks removed | Orphaned Shorts removed; KG edges cleaned; recommendations refreshed |
| SYS-10 | **Module Auto-Update** | New Short generated that falls within module's topic scope; existing Short within module updated/deleted | Module contents, metadata, and progress recalculated |
| SYS-11 | **Spaced Repetition Scheduling** | Time elapsed since Short was last reviewed | Short surfaced in the feed or a review notification sent based on optimal review interval |
| SYS-12 | **Quiz Generation** | Short marked as completed; spaced repetition review interval reached | System generates quiz questions from Short content; results update user profile |
| SYS-13 | **Exploration Question Research** | User taps an exploration question on a Short | System checks if sufficient source material exists; if so, generates new Shorts on the sub-topic |
| SYS-14 | **Cold Start Bootstrapping** | New user completes onboarding with initial interests | Content-based recommendations generated from interest topics; initial Shorts fetched from default/selected sources |
| SYS-15 | **Streak Tracking** | Daily user activity detected / not detected | Current streak incremented or reset; best streak updated; streak-at-risk notifications triggered |
| SYS-16 | **Processing Task Tracking** | Any note processing begins | Task created (pending → processing → completed/failed); failed tasks logged with errors for debugging |
| SYS-17 | **Multi-Stage Deduplication on Ingestion** | New chunk embedding generated | Canonicalize → exact hash check → near-duplicate detection (MinHash/LSH or SimHash) → semantic similarity check (ChromaDB cosine ≥ 0.85) → optional cross-encoder verification for borderline cases. All decisions logged for auditability. |
| SYS-18 | **Difficulty Adaptation** | User interaction patterns change (faster/slower completion, more/fewer skips) | Difficulty preference updated; recommendation scoring weights adjusted toward appropriate difficulty level |
| SYS-19 | **Contextual Factor Adaptation** | Time-of-day, device type, session duration patterns detected | Content selection adjusted (e.g., lighter content for short evening sessions, deeper content for long weekend sessions) |
| SYS-20 | **Source Auto-Summary Generation** | New source successfully ingested and chunks created | System generates source summary, key topics/concepts, and 3–5 exploration questions; updates concept inventory |
| SYS-21 | **Concept Inventory Update** | New Shorts added, updated, merged, or deleted | Concept clusters re-evaluated incrementally; new concepts added, stale concepts pruned; importance scores recalculated |
| SYS-22 | **Cross-Modal Duplicate Detection** | Content ingested from a different media type than existing content | Embedding comparison across modalities detects if the new content semantically duplicates existing chunks from another media type |

---

## 7. Data Entities Summary

| Entity | Storage | Key Fields |
|--------|---------|-----------|
| **User** | Firestore `users` | id, email, displayName, photoURL, qualities (learningMode, strengths, weaknesses), preferences (interests, goals, language), settings (theme, fontSize), stats (completedCount, streakDays, bestStreak, lastActivityDate), recommendedArticleId |
| **Note** | Firestore `notes` | id, userId, type (TEXT/IMAGE/AUDIO/LINK/VIDEO/FILE), title, content, extractedText, processed (bool), chunkIds[], timestamps |
| **Chunk** | ChromaDB + Firestore metadata | id, noteId, userId, text, embedding[], similarity scores, metadata, timestamps |
| **Short (Article)** | Firestore `articles` | id, userId, title, content (Markdown), summary, topics[], tags[], difficulty (0.0–1.0), prerequisites[], relatedArticles[], citations (noteId, chunkId), explorationPrompts[], engagement metrics, embedding[], timestamps |
| **Module** | Firestore `modules` | id, userId, name, description, topics[], shortIds[], type (auto/manual), adaptiveRules[], progress stats, timestamps |
| **UserInteraction** | Firestore `users/{id}/interactions` | id, articleId, type (STARTED/COMPLETED/SKIPPED/BOOKMARKED), timestamp, metadata (timeSpent, scrollDepth, device) |
| **Bookmark** | Firestore `users/{id}/bookmarks` | articleId, addedAt |
| **ContentSource** | Firestore `sources` | id, userId, name, type (website/rss/newsletter/api), url, fetchFrequency, status (active/paused/error), defaultTopics[], stats, timestamps |
| **ProcessingTask** | Firestore `processing_tasks` | id, userId, noteId, taskType (ingest/update/delete), status (pending/processing/completed/failed), errorMessage, timestamps |
| **KnowledgeGraph** | Firestore/Neo4j | concepts (id, name, description, level, aliases), relationships (sourceId, targetId, type, strength), articleMappings (articleId, conceptIds, coverage) |
| **LearningPath** | Firestore `learning_paths` | id, userId, name, type (system/user/curated), articles[] (ordered, required/optional), prerequisites[], adaptiveRules[], stats, timestamps |
| **Recommendation** | Firestore (computed) | id, userId, recommendations[] (articleId, score, reason, explanation), algorithm metadata, user state snapshot, feedback |
| **Quiz/Assessment** | Firestore `quizzes` | id, userId, articleId, questions[], answers[], score, retentionMetrics, timestamp |
| **Analytics** | Firestore `analytics` | userId, period, userMetrics, contentMetrics, learningMetrics, systemMetrics, insights[] |
| **AppConfig** | Firestore `app_config` | topics[], difficulties[], topicDefinitions, featureFlags[] |

---

*This document is derived from the comprehensive research in [OVERVIEW.md](OVERVIEW.md), [RESEARCH.md](RESEARCH.md), [Project.md](Project.md), and [NotebookLM.md](NotebookLM.md). It serves as the single source of truth for all capabilities, requirements, and behaviors of the Geeky application.*
