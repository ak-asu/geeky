"""Sync service — batch upload offline interaction events.

Handles batch syncing of interaction events from the Flutter client
and updates the user's learning streak based on interaction timestamps.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from app.models.interaction import InteractionCreate, InteractionDocument

logger = logging.getLogger(__name__)


class SyncService:
    """Interaction batch sync and streak management.

    Args:
        interaction_repo: Interaction document repository.
        user_repo: User repository (for streak updates).
    """

    def __init__(
        self,
        *,
        interaction_repo: Any,
        user_repo: Any,
    ) -> None:
        self._interaction_repo = interaction_repo
        self._user_repo = user_repo

    async def batch_sync(
        self, user_id: str, interactions: list[InteractionCreate]
    ) -> dict:
        """Batch sync interaction events from the client.

        Converts InteractionCreate items to InteractionDocument,
        writes them in batch, and updates the user's streak.

        Returns sync results with counts.
        """
        if not interactions:
            return {"synced": 0, "failed": 0}

        # Convert to documents
        docs = []
        for interaction in interactions:
            doc = InteractionDocument(
                article_id=interaction.article_id,
                type=interaction.type,
                timestamp=interaction.timestamp,
                time_spent=interaction.time_spent,
                scroll_depth=interaction.scroll_depth,
                feedback_type=interaction.feedback_type,
                navigation_direction=interaction.navigation_direction,
                from_article_id=interaction.from_article_id,
                device=interaction.device,
                session_id=interaction.session_id,
            )
            docs.append(doc)

        synced = await self._interaction_repo.create_batch(user_id, docs)

        # Update streak based on latest interaction timestamp
        await self._update_streak(user_id)

        return {"synced": synced, "failed": len(interactions) - synced}

    async def _update_streak(self, user_id: str) -> None:
        """Update user streak based on interaction activity.

        Computes whether today counts as an active day and updates
        the streak accordingly.
        """
        user = await self._user_repo.get(user_id)
        if not user:
            return

        today = datetime.now(timezone.utc).date().isoformat()
        last_active = user.streak.last_active_date

        if last_active == today:
            # Already counted today
            return

        yesterday = (
            datetime.now(timezone.utc).date() - timedelta(days=1)
        ).isoformat()

        if last_active == yesterday:
            new_current = user.streak.current + 1
        else:
            new_current = 1

        new_longest = max(user.streak.longest, new_current)

        # Rotate weekly activity
        weekly = user.streak.weekly_activity[1:] + [True]

        await self._user_repo.update(user_id, {
            "streak.current": new_current,
            "streak.longest": new_longest,
            "streak.lastActiveDate": today,
            "streak.weeklyActivity": weekly,
        })
