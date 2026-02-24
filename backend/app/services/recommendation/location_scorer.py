"""Geographic relevance scorer for recommendation engine.

Computes a 0.0–1.0 score representing how geographically relevant a short's
location entities are to the user's home region. Used as an additive boost
(~12% weight) in the multi-factor recommendation scorer.

Design principles:
- Coarse matching only — city/state/country level, no precise coordinates.
- Graceful degradation — returns 0.0 when either side has no location data.
- Deterministic and fast — pure string matching, no I/O.
"""

from __future__ import annotations

import re


class LocationScorer:
    """Computes geographic relevance between content locations and user region.

    Matching strategy (ordered by specificity):
    1. Exact token match — "Arizona" in content and "Arizona" in user region.
    2. Country code match — "US" appears in both.
    3. Partial label overlap — shared words between location labels.

    Returns a score in [0.0, 1.0]:
    - 1.0: strong match (explicit location overlap)
    - 0.5: partial match (shared country/region token)
    - 0.0: no location data or no match
    """

    def compute_score(
        self,
        content_locations: list[str],
        user_region: str | None,
    ) -> float:
        """Score how geographically relevant content is to the user's region.

        Args:
            content_locations: Location entities extracted from the short
                               (e.g. ["Arizona", "Phoenix", "United States"]).
            user_region: The user's home region label
                         (e.g. "Arizona, US" or "London, UK").

        Returns:
            Float in [0.0, 1.0]. 0.0 if either side has no location data.
        """
        if not content_locations or not user_region:
            return 0.0

        # Normalize: lowercase, split into tokens for flexible matching
        user_tokens = _tokenize(user_region)
        if not user_tokens:
            return 0.0

        best_score = 0.0
        for location in content_locations:
            loc_tokens = _tokenize(location)
            if not loc_tokens:
                continue
            score = _token_overlap_score(loc_tokens, user_tokens)
            if score > best_score:
                best_score = score
                if best_score >= 1.0:
                    break  # Can't do better

        return round(best_score, 4)


def _tokenize(label: str) -> set[str]:
    """Split a location label into lowercase word tokens, stripping punctuation."""
    # Split on whitespace and commas; remove empty tokens shorter than 2 chars
    tokens = re.split(r"[\s,]+", label.lower())
    return {t for t in tokens if len(t) >= 2}


def _token_overlap_score(loc_tokens: set[str], user_tokens: set[str]) -> float:
    """Compute Jaccard-like overlap between two token sets.

    Returns:
        1.0 if all location tokens are covered by the user region.
        0.5 if any token overlaps (partial match).
        0.0 if no overlap.
    """
    overlap = loc_tokens & user_tokens
    if not overlap:
        return 0.0
    # Full containment: every location token found in user region
    if overlap == loc_tokens:
        return 1.0
    # Partial overlap: at least one shared token
    return 0.5
