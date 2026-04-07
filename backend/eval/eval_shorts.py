"""eval_shorts.py — Evaluate AI-generated Short quality against source documents.

Usage (run from the backend/ directory):
    python -m eval.eval_shorts
    python -m eval.eval_shorts --corpus-dir eval/corpus --output eval/results/latest.json
    python -m eval.eval_shorts --verbose

What it tests:
    Given a document -> pipeline generates Shorts -> judge evaluates Shorts quality.
    No HTTP server, no Celery, no Redis needed. Calls PipelineOrchestrator directly.

Dimensions scored:
    1. Factual Accuracy  - per Short, Claude counts unsupported claims vs source chunk
    2. Coverage          - doc-level, Claude identifies key topics absent from all Shorts
    3. Redundancy        - pairwise TF-IDF cosine similarity between Shorts (pure Python)
    4. Difficulty Cal.   - Pearson r between Geeky's 0-1 score and FKGL (scaled 0-1)

Generator: Gemini 2.5 Flash (GEMINI_API_KEY from .env)
Judge:     Claude Sonnet 4.6 (CLAUDE_API_KEY from .env) — cross-model reduces self-serving bias
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import math
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Path setup — make `app` importable when running from backend/
# ---------------------------------------------------------------------------
_BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_BACKEND_DIR))
os.chdir(_BACKEND_DIR)  # ensures .env is found by pydantic-settings

from app.config import Settings  # noqa: E402
from app.services.llm.gemini_llm import GeminiLLM  # noqa: E402
from app.services.pipeline.orchestrator import PipelineOrchestrator  # noqa: E402

logging.basicConfig(
    level=logging.WARNING,
    format="%(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("eval_shorts")

# ---------------------------------------------------------------------------
# Document categories (matched by filename prefix)
# ---------------------------------------------------------------------------
_CATEGORIES = {
    "01": ("Short news article", "Low"),
    "02": ("Wikipedia-style article", "Medium"),
    "03": ("Academic paper", "High"),
    "04": ("Textbook chapter", "Very High"),
}

# 04_textbook.txt produces ~10 natural chunks; cap at 7 to show coverage loss
_CAP_OVERRIDES = {"04": 7}

# ---------------------------------------------------------------------------
# Lightweight stubs for non-LLM pipeline dependencies
# ---------------------------------------------------------------------------


class _StubEmbedder:
    """Zero-vector embeddings — not needed for Short quality eval."""

    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        return [[0.0] * 768 for _ in texts]

    async def embed_query(self, query: str) -> list[float]:
        return [0.0] * 768


class _StubNER:
    """Empty NER — does not affect Short content."""

    async def extract_entities(self, text: str) -> list:
        return []


class _StubParser:
    """Pass-through parser for plain text input."""

    async def parse(self, content: bytes, content_type: str) -> Any:
        from app.services.pipeline.extractor.base import ParsedDocument  # noqa: PLC0415

        return ParsedDocument(text=content.decode("utf-8", errors="replace"), sections=[])


# ---------------------------------------------------------------------------
# Claude Sonnet 4.6 judge
# ---------------------------------------------------------------------------


class ClaudeJudge:
    """Synchronous Anthropic client wrapped for async use."""

    def __init__(self, api_key: str, model: str = "claude-sonnet-4-6") -> None:
        import anthropic  # noqa: PLC0415

        self._client = anthropic.Anthropic(api_key=api_key)
        self._model = model

    async def judge(self, prompt: str) -> str:
        """Call Claude synchronously in a thread to keep the event loop free."""
        import anthropic  # noqa: PLC0415

        def _call() -> str:
            msg = self._client.messages.create(
                model=self._model,
                max_tokens=512,
                temperature=0,
                messages=[{"role": "user", "content": prompt}],
            )
            return msg.content[0].text

        return await asyncio.to_thread(_call)


# ---------------------------------------------------------------------------
# FKGL utilities
# ---------------------------------------------------------------------------

_VOWELS = re.compile(r"[aeiouy]+", re.IGNORECASE)
_SENTENCE_END = re.compile(r"[.!?]+")


def _count_syllables(word: str) -> int:
    word = re.sub(r"[^a-zA-Z]", "", word)
    if not word:
        return 0
    count = len(_VOWELS.findall(word))
    if word.endswith("e") and count > 1:
        count -= 1
    return max(1, count)


def _fkgl(text: str) -> float:
    sentences = [s.strip() for s in _SENTENCE_END.split(text) if s.strip()]
    words = text.split()
    if not sentences or not words:
        return 8.0
    n_sentences = max(1, len(sentences))
    n_words = max(1, len(words))
    n_syllables = sum(_count_syllables(w) for w in words)
    grade = 0.39 * (n_words / n_sentences) + 11.8 * (n_syllables / n_words) - 15.59
    return max(1.0, grade)


def _fkgl_to_01(grade: float) -> float:
    return min(1.0, max(0.0, (grade - 1.0) / 17.0))


# ---------------------------------------------------------------------------
# Redundancy — TF-IDF cosine (pure Python, no extra deps)
# ---------------------------------------------------------------------------


def _tfidf_cosine(texts: list[str]) -> list[tuple[int, int, float]]:
    if len(texts) < 2:
        return []

    def tokenize(t: str) -> list[str]:
        return re.findall(r"[a-z]+", t.lower())

    tokenized = [tokenize(t) for t in texts]
    vocab_list = sorted({tok for tokens in tokenized for tok in tokens})
    vocab_idx = {w: i for i, w in enumerate(vocab_list)}
    n, V = len(texts), len(vocab_list)

    tf = [[0.0] * V for _ in range(n)]
    for doc_i, tokens in enumerate(tokenized):
        for tok in tokens:
            tf[doc_i][vocab_idx[tok]] += 1
        total = sum(tf[doc_i]) or 1
        tf[doc_i] = [x / total for x in tf[doc_i]]

    df = [sum(1 for d in range(n) if tf[d][j] > 0) for j in range(V)]
    idf = [math.log(1 + (n - df[j] + 0.5) / (df[j] + 0.5)) for j in range(V)]
    tfidf = [[tf[i][j] * idf[j] for j in range(V)] for i in range(n)]

    def dot(a: list[float], b: list[float]) -> float:
        return sum(x * y for x, y in zip(a, b))

    def norm(a: list[float]) -> float:
        return math.sqrt(sum(x * x for x in a))

    return [
        (i, j, round(dot(tfidf[i], tfidf[j]) / (norm(tfidf[i]) * norm(tfidf[j])), 4))
        for i in range(n) for j in range(i + 1, n)
        if (norm(tfidf[i]) * norm(tfidf[j])) > 1e-9
        and dot(tfidf[i], tfidf[j]) / (norm(tfidf[i]) * norm(tfidf[j])) > 0.05
    ]


# ---------------------------------------------------------------------------
# Judge prompts
# ---------------------------------------------------------------------------

_ACCURACY_PROMPT = """\
You are evaluating whether an AI-generated educational "Short" faithfully represents its source document.

FULL SOURCE DOCUMENT:
\"\"\"
{source}
\"\"\"

AI-GENERATED SHORT:
Title: {title}
Content: {content}

Count the number of statements in the Short's Content that CANNOT be directly verified or \
reasonably inferred from ANYWHERE in the Source Document. Include hallucinated facts, \
incorrect numbers, wrong names, and invented claims not present in the source.

Respond with a JSON object ONLY — no markdown, no extra text:
{{
  "unsupported_count": <integer>,
  "total_statements": <integer — total factual statements in the Short>,
  "reasoning": "<one sentence on main issues, or 'None' if accurate>"
}}"""

_COVERAGE_PROMPT = """\
You are evaluating whether a set of AI-generated "Shorts" collectively covers all major topics \
from a source document.

FULL SOURCE DOCUMENT:
\"\"\"
{document}
\"\"\"

SHORT TITLES:
{short_titles}

FULL CONTENT OF ALL SHORTS:
{short_contents}

Identify key topics or concepts from the source document that are COMPLETELY ABSENT from all \
Shorts — important information dropped during summarization.

Respond with a JSON object ONLY — no markdown, no extra text:
{{
  "missing_topics": ["<topic 1>", "<topic 2>", ...],
  "total_key_topics_in_source": <integer>,
  "covered_count": <integer>
}}"""


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class ShortEvalResult:
    short_title: str
    short_content: str
    difficulty: float
    fkgl_score: float
    fkgl_01: float
    unsupported_count: int
    total_statements: int
    accuracy_pct: float
    accuracy_reasoning: str


@dataclass
class DocumentEvalResult:
    filename: str
    category: str
    complexity: str
    word_count: int
    shorts_generated: int
    shorts: list[ShortEvalResult] = field(default_factory=list)
    missing_topics: list[str] = field(default_factory=list)
    total_key_topics: int = 0
    covered_count: int = 0
    redundant_pairs: int = 0
    total_pairs: int = 0
    difficulty_r: float = 0.0

    @property
    def factual_accuracy_pct(self) -> float:
        totals = sum(s.total_statements for s in self.shorts)
        if totals == 0:
            return 100.0
        return round(100.0 * (1 - sum(s.unsupported_count for s in self.shorts) / totals), 1)

    @property
    def coverage_pct(self) -> float:
        if self.total_key_topics == 0:
            return 100.0
        return round(100.0 * self.covered_count / self.total_key_topics, 1)

    @property
    def redundancy_pct(self) -> float:
        if self.total_pairs == 0:
            return 0.0
        return round(100.0 * self.redundant_pairs / self.total_pairs, 1)


# ---------------------------------------------------------------------------
# Core evaluation
# ---------------------------------------------------------------------------


def _parse_json_response(raw: str, fallback: dict) -> dict:
    """Extract the first JSON object from a Claude response."""
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass
    return fallback


async def _evaluate_document(
    doc_path: Path,
    judge: ClaudeJudge,
    orchestrator: PipelineOrchestrator,
    category_key: str,
) -> DocumentEvalResult:
    category_label, complexity = _CATEGORIES.get(category_key, ("Unknown", "Unknown"))
    text = doc_path.read_text(encoding="utf-8")
    word_count = len(text.split())

    # Strip markdown headings so paragraph-level chunking is used instead of
    # one-chunk-per-section (which over-fragments docs with many ## headings).
    plain_text = re.sub(r"^#{1,6}\s+.*$", "", text, flags=re.MULTILINE)
    plain_text = re.sub(r"\n{3,}", "\n\n", plain_text).strip()

    print(f"  Processing {doc_path.name} ({word_count} words)...", flush=True)

    result_dict = await orchestrator.process(
        note_id=f"eval_{doc_path.stem}",
        content=plain_text,
        note_type="text",
    )

    shorts = result_dict.get("shorts", [])
    n_shorts = len(shorts)
    print(f"    -> {n_shorts} Shorts generated, running Claude judge...", flush=True)

    eval_result = DocumentEvalResult(
        filename=doc_path.name,
        category=category_label,
        complexity=complexity,
        word_count=word_count,
        shorts_generated=n_shorts,
    )

    if not shorts:
        return eval_result

    # Pass the full document to Claude — Claude Sonnet 4.6 has a 200K context
    # window so even the longest corpus file fits easily.
    judge_source = text

    # ---- Per-Short accuracy (sequential to avoid rate limits) ----
    for i, short in enumerate(shorts):
        fkgl = _fkgl(short["content"])
        fkgl_01 = _fkgl_to_01(fkgl)

        raw = await judge.judge(
            _ACCURACY_PROMPT.format(
                source=judge_source,
                title=short["title"],
                content=short["content"],
            )
        )
        parsed = _parse_json_response(raw, {"unsupported_count": 0, "total_statements": 10, "reasoning": "parse error"})

        unsupported = int(parsed.get("unsupported_count", 0))
        total_stmts = max(1, int(parsed.get("total_statements", 10)))
        acc_pct = round(100.0 * (1 - unsupported / total_stmts), 1)

        eval_result.shorts.append(ShortEvalResult(
            short_title=short["title"],
            short_content=short["content"],
            difficulty=short.get("difficulty", 0.5),
            fkgl_score=round(fkgl, 2),
            fkgl_01=round(fkgl_01, 3),
            unsupported_count=unsupported,
            total_statements=total_stmts,
            accuracy_pct=acc_pct,
            accuracy_reasoning=parsed.get("reasoning", ""),
        ))
        print(f"    Short {i+1}/{n_shorts}: accuracy={acc_pct:.0f}%", flush=True)

    # ---- Document-level coverage ----
    raw_cov = await judge.judge(
        _COVERAGE_PROMPT.format(
            document=text[:8000],
            short_titles="\n".join(f"- {s['title']}" for s in shorts),
            short_contents="\n\n".join(
                f"[Short {i+1}: {s['title']}]\n{s['content']}"
                for i, s in enumerate(shorts)
            )[:6000],
        )
    )
    cov = _parse_json_response(
        raw_cov,
        {"missing_topics": [], "total_key_topics_in_source": n_shorts, "covered_count": n_shorts},
    )
    eval_result.missing_topics = cov.get("missing_topics", [])
    eval_result.total_key_topics = max(1, int(cov.get("total_key_topics_in_source", n_shorts)))
    eval_result.covered_count = int(cov.get("covered_count", n_shorts))

    # ---- Redundancy ----
    pairs = _tfidf_cosine([s["content"] for s in shorts])
    redundant = [p for p in pairs if p[2] > 0.85]
    eval_result.redundant_pairs = len(redundant)
    eval_result.total_pairs = n_shorts * (n_shorts - 1) // 2

    # ---- Difficulty calibration ----
    eval_result.difficulty_r = _pearson_r(
        [s.difficulty for s in eval_result.shorts],
        [s.fkgl_01 for s in eval_result.shorts],
    )

    return eval_result


def _pearson_r(xs: list[float], ys: list[float]) -> float:
    n = len(xs)
    if n < 2:
        return 0.0
    mx, my = sum(xs) / n, sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    dy = math.sqrt(sum((y - my) ** 2 for y in ys))
    if dx < 1e-9 or dy < 1e-9:
        return 0.0
    return round(num / (dx * dy), 3)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------


def _print_table(results: list[DocumentEvalResult]) -> None:
    header = f"{'File':<30} {'Words':>6} {'Shorts':>8} {'Accuracy':>10} {'Coverage':>10} {'Redund.':>8} {'Diff r':>7}"
    sep = "=" * len(header)
    print(f"\n{sep}")
    print("  SHORT QUALITY EVALUATION RESULTS  (judge: Claude Sonnet 4.6)")
    print(sep)
    print(header)
    print("-" * len(header))
    for r in results:
        shorts_str = f"{r.shorts_generated}" + (" (cap)" if "04" in r.filename else "")
        print(
            f"{r.filename:<30} {r.word_count:>6} {shorts_str:>8}"
            f" {r.factual_accuracy_pct:>9.1f}%"
            f" {r.coverage_pct:>9.1f}%"
            f" {r.redundancy_pct:>7.1f}%"
            f" {r.difficulty_r:>7.3f}"
        )
    print(sep)


def _print_verbose(results: list[DocumentEvalResult]) -> None:
    for doc_result in results:
        sep = "-" * 72
        print(f"\n{sep}")
        print(f"  {doc_result.filename}  [{doc_result.category} / {doc_result.complexity}]")
        print(sep)
        for i, s in enumerate(doc_result.shorts):
            flag = "  [OK]" if s.accuracy_pct >= 90 else "  [!]"
            print(f"  Short {i+1}: {s.short_title}{flag}")
            print(f"    accuracy={s.accuracy_pct:.0f}%  difficulty={s.difficulty:.2f}  "
                  f"FKGL={s.fkgl_score:.1f} (scaled {s.fkgl_01:.2f})")
            if s.accuracy_reasoning and s.accuracy_reasoning.lower() not in ("none", ""):
                print(f"    Note: {s.accuracy_reasoning}")
        if doc_result.missing_topics:
            print(f"\n  Missing topics ({len(doc_result.missing_topics)} identified by Claude):")
            for t in doc_result.missing_topics[:6]:
                print(f"    - {t}")
            if len(doc_result.missing_topics) > 6:
                print(f"    ... and {len(doc_result.missing_topics) - 6} more")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


async def main(corpus_dir: str, output_path: str, verbose: bool) -> None:
    settings = Settings()

    # Read CLAUDE_API_KEY from .env (not in pydantic Settings, read directly)
    claude_api_key = os.environ.get("CLAUDE_API_KEY") or _read_dotenv_key(".env", "CLAUDE_API_KEY")
    if not claude_api_key:
        print("ERROR: CLAUDE_API_KEY not found in .env")
        sys.exit(1)
    if not settings.gemini_api_key:
        print("ERROR: GEMINI_API_KEY not set in .env")
        sys.exit(1)

    gen_llm = GeminiLLM(
        api_key=settings.gemini_api_key,
        model=settings.gemini_model,
        timeout_seconds=90.0,
    )
    judge = ClaudeJudge(api_key=claude_api_key, model="claude-sonnet-4-6")

    corpus_path = Path(corpus_dir)
    if not corpus_path.exists():
        print(f"ERROR: corpus directory not found: {corpus_path.resolve()}")
        sys.exit(1)

    doc_files = sorted(corpus_path.glob("*.txt"))
    if not doc_files:
        print(f"ERROR: no .txt files found in {corpus_path.resolve()}")
        sys.exit(1)

    print(f"\nGenerator : {settings.gemini_model}")
    print(f"Judge     : Claude Sonnet 4.6")
    print(f"Corpus    : {corpus_path.resolve()} ({len(doc_files)} documents)\n")

    all_results: list[DocumentEvalResult] = []

    for doc_path in doc_files:
        category_key = doc_path.stem[:2]
        cap = _CAP_OVERRIDES.get(category_key, settings.anti_density_max_per_source)

        eval_settings = Settings(
            gemini_api_key=settings.gemini_api_key,
            gemini_model=settings.gemini_model,
            chunk_target_words=400,
            chunk_overlap_words=50,
            anti_density_max_per_source=cap,
            dedup_near_threshold=0.9,
        )

        orchestrator = PipelineOrchestrator(
            document_parser=_StubParser(),
            embedding_provider=_StubEmbedder(),
            llm_provider=gen_llm,
            ner_extractor=_StubNER(),
            settings=eval_settings,
        )

        result = await _evaluate_document(doc_path, judge, orchestrator, category_key)
        all_results.append(result)

    _print_table(all_results)
    if verbose:
        _print_verbose(all_results)

    # Save JSON
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as f:
        json.dump(
            [
                {
                    "filename": r.filename,
                    "category": r.category,
                    "complexity": r.complexity,
                    "word_count": r.word_count,
                    "shorts_generated": r.shorts_generated,
                    "factual_accuracy_pct": r.factual_accuracy_pct,
                    "coverage_pct": r.coverage_pct,
                    "redundancy_pct": r.redundancy_pct,
                    "difficulty_pearson_r": r.difficulty_r,
                    "missing_topics": r.missing_topics,
                    "shorts": [
                        {
                            "title": s.short_title,
                            "difficulty": s.difficulty,
                            "fkgl_grade": s.fkgl_score,
                            "fkgl_01": s.fkgl_01,
                            "accuracy_pct": s.accuracy_pct,
                            "unsupported_count": s.unsupported_count,
                            "total_statements": s.total_statements,
                            "reasoning": s.accuracy_reasoning,
                        }
                        for s in r.shorts
                    ],
                }
                for r in all_results
            ],
            f,
            indent=2,
            ensure_ascii=False,
        )
    print(f"\nDetailed results -> {output.resolve()}\n")


def _read_dotenv_key(dotenv_path: str, key: str) -> str | None:
    """Minimal .env reader for keys not in pydantic Settings."""
    try:
        for line in Path(dotenv_path).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith(key + "=") and not line.startswith("#"):
                return line.split("=", 1)[1].strip()
    except FileNotFoundError:
        pass
    return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate Short quality vs source documents")
    parser.add_argument("--corpus-dir", default="eval/corpus")
    parser.add_argument("--output", default="eval/results/latest.json")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()
    asyncio.run(main(args.corpus_dir, args.output, args.verbose))
