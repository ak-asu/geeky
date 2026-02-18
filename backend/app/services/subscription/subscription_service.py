"""Subscription quota enforcement service.

Checks and enforces per-tier limits for notes, sources, and RAG queries.
Raises PremiumRequiredError when a free user exceeds their tier limits.
"""
from __future__ import annotations

import logging
from datetime import date
from typing import Any

from app.exceptions import PremiumRequiredError
from app.models.subscription import ENTITLEMENTS

logger = logging.getLogger(__name__)


class SubscriptionService:
    """Enforces subscription tier limits.

    Raises PremiumRequiredError on quota violations so the API layer can
    return a 402 Payment Required response.

    Args:
        user_repo: User repository (to fetch subscription tier and RAG counters).
        note_repo: Note repository (to count existing notes).
        source_repo: Source repository (to count existing sources).
    """

    def __init__(self, *, user_repo: Any, note_repo: Any, source_repo: Any) -> None:
        self._user_repo = user_repo
        self._note_repo = note_repo
        self._source_repo = source_repo

    async def check_notes_quota(self, user_id: str) -> None:
        """Raise PremiumRequiredError if the user is at or over the note limit.

        Premium users are always allowed through (-1 = unlimited).
        """
        user = await self._user_repo.get(user_id)
        tier = user.subscription_tier.value if user else "free"
        entitlements = ENTITLEMENTS.get(tier, ENTITLEMENTS["free"])

        if entitlements.max_notes == -1:
            return  # unlimited

        count = await self._note_repo.count(user_id)
        if count >= entitlements.max_notes:
            raise PremiumRequiredError(
                f"Free tier note limit of {entitlements.max_notes} reached. "
                "Upgrade to Premium for unlimited notes."
            )

    async def check_sources_quota(self, user_id: str) -> None:
        """Raise PremiumRequiredError if the user is at or over the source limit."""
        user = await self._user_repo.get(user_id)
        tier = user.subscription_tier.value if user else "free"
        entitlements = ENTITLEMENTS.get(tier, ENTITLEMENTS["free"])

        if entitlements.max_sources == -1:
            return  # unlimited

        count = await self._source_repo.count(user_id)
        if count >= entitlements.max_sources:
            raise PremiumRequiredError(
                f"Free tier source limit of {entitlements.max_sources} reached. "
                "Upgrade to Premium for unlimited sources."
            )

    async def check_rag_quota(self, user_id: str) -> None:
        """Raise PremiumRequiredError if the user exceeded their daily RAG query limit.

        Also increments the counter for successful checks. Resets automatically
        on a new calendar day (UTC).
        """
        user = await self._user_repo.get(user_id)
        tier = user.subscription_tier.value if user else "free"
        entitlements = ENTITLEMENTS.get(tier, ENTITLEMENTS["free"])

        if entitlements.rag_queries_per_day == -1:
            return  # unlimited

        today = date.today().isoformat()

        if not user or user.rag_queries_date != today:
            # New day — reset counter and allow this query
            await self._user_repo.update(user_id, {
                "ragQueriesToday": 1,
                "ragQueriesDate": today,
            })
            return

        if user.rag_queries_today >= entitlements.rag_queries_per_day:
            raise PremiumRequiredError(
                f"Daily RAG query limit of {entitlements.rag_queries_per_day} reached. "
                "Upgrade to Premium for unlimited queries."
            )

        await self._user_repo.update(user_id, {
            "ragQueriesToday": user.rag_queries_today + 1,
        })
        logger.debug(
            "RAG quota: user=%s used=%d limit=%d",
            user_id, user.rag_queries_today + 1, entitlements.rag_queries_per_day,
        )
