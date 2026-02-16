"""Analytics aggregator — computes dashboard metrics from existing data.

Reads from existing repositories (no new data stores). All queries
are user_id scoped for data isolation (SE-03).
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from app.models.analytics import (
    Achievement,
    DashboardResponse,
    MasteryDistribution,
    StreakResponse,
    StudyActivity,
    TopicProgress,
)

logger = logging.getLogger(__name__)


# Achievement definitions
_ACHIEVEMENTS = [
    ("first_note", "First Note", "Created your first note"),
    ("ten_notes", "Note Collector", "Created 10 notes"),
    ("first_review", "First Review", "Completed your first review"),
    ("streak_7", "Week Warrior", "Maintained a 7-day study streak"),
    ("streak_30", "Monthly Master", "Maintained a 30-day study streak"),
    ("shorts_50", "Half Century", "Generated 50 shorts"),
    ("shorts_100", "Century Club", "Generated 100 shorts"),
    ("concepts_25", "Knowledge Builder", "Discovered 25 concepts"),
    ("mastery_first", "First Mastery", "Mastered your first topic"),
]


class AnalyticsAggregator:
    """Computes user analytics metrics from existing data sources.

    Args:
        note_repo: Note repository.
        short_repo: Short repository.
        concept_repo: Concept repository.
        review_state_repo: Review state repository.
        interaction_repo: Interaction repository.
        quiz_attempt_repo: Quiz attempt repository.
        user_repo: User repository.
    """

    def __init__(
        self,
        *,
        note_repo: Any,
        short_repo: Any,
        concept_repo: Any,
        review_state_repo: Any,
        interaction_repo: Any,
        quiz_attempt_repo: Any,
        user_repo: Any,
    ) -> None:
        self._note_repo = note_repo
        self._short_repo = short_repo
        self._concept_repo = concept_repo
        self._review_state_repo = review_state_repo
        self._interaction_repo = interaction_repo
        self._quiz_attempt_repo = quiz_attempt_repo
        self._user_repo = user_repo

    async def get_dashboard(self, user_id: str) -> DashboardResponse:
        """Compute full dashboard metrics for a user (AN-01)."""
        # Gather counts
        note_count = await self._note_repo.count(user_id)
        short_count = await self._short_repo.count(user_id)
        concept_count = await self._concept_repo.count(user_id)

        # Streak
        streak = await self.get_streak(user_id)

        # Mastery distribution
        mastery = await self.get_mastery_distribution(user_id)

        # Topic progress
        topics_progress = await self._compute_topic_progress(user_id)

        # Recent activity (last 7 days)
        recent_activity = await self._compute_recent_activity(user_id)

        # Completed shorts (those with at least one review)
        completed = mastery.review + mastery.relearning

        # Time spent
        total_time = await self._compute_total_time(user_id)

        # Achievements
        achievements = await self._compute_achievements(
            user_id, note_count, short_count, concept_count, streak, mastery
        )

        return DashboardResponse(
            streak=streak,
            topics_progress=topics_progress,
            mastery=mastery,
            recent_activity=recent_activity,
            total_notes=note_count,
            total_shorts=short_count,
            total_concepts=concept_count,
            total_shorts_completed=completed,
            total_time_spent_minutes=total_time,
            achievements=achievements,
        )

    async def get_streak(self, user_id: str) -> StreakResponse:
        """Get the user's study streak (AN-02)."""
        user = await self._user_repo.get(user_id, user_id)
        if not user:
            return StreakResponse()

        streak_info = user.streak
        return StreakResponse(
            current=streak_info.current,
            longest=streak_info.longest,
            last_active_date=streak_info.last_active_date,
            weekly_activity=streak_info.weekly_activity,
        )

    async def get_mastery_distribution(self, user_id: str) -> MasteryDistribution:
        """Get mastery distribution across review states (AN-03)."""
        review_states = await self._review_state_repo.query(user_id, limit=5000)

        counts = defaultdict(int)
        for rs in review_states:
            state = rs.state.lower() if rs.state else "new"
            counts[state] += 1

        total = len(review_states)
        return MasteryDistribution(
            new=counts.get("new", 0),
            learning=counts.get("learning", 0),
            review=counts.get("review", 0),
            relearning=counts.get("relearning", 0),
            total=total,
        )

    async def _compute_topic_progress(self, user_id: str) -> list[TopicProgress]:
        """Compute mastery per topic from shorts + review states."""
        shorts = await self._short_repo.query(user_id, limit=5000)
        review_states = await self._review_state_repo.query(user_id, limit=5000)

        # Map short_id → review state
        rs_by_short = {rs.short_id: rs for rs in review_states}

        # Group by topic
        topic_data: dict[str, dict] = defaultdict(
            lambda: {"total": 0, "completed": 0, "mastery_sum": 0.0}
        )

        for short in shorts:
            rs = rs_by_short.get(short.id)
            is_completed = rs is not None and rs.state in ("review", "relearning")
            mastery = self._state_to_mastery(rs.state if rs else "new")

            for topic in short.topics:
                topic_data[topic]["total"] += 1
                if is_completed:
                    topic_data[topic]["completed"] += 1
                topic_data[topic]["mastery_sum"] += mastery

        results = []
        for topic, data in sorted(topic_data.items()):
            avg_mastery = data["mastery_sum"] / data["total"] if data["total"] > 0 else 0.0
            results.append(
                TopicProgress(
                    topic=topic,
                    shorts_completed=data["completed"],
                    total_shorts=data["total"],
                    mastery=round(avg_mastery, 2),
                )
            )

        return results

    async def _compute_recent_activity(self, user_id: str) -> list[StudyActivity]:
        """Compute review activity for the last 7 days."""
        now = datetime.now(timezone.utc)
        activities = []

        for days_ago in range(6, -1, -1):
            date = now - timedelta(days=days_ago)
            date_str = date.strftime("%Y-%m-%d")

            # Count interactions for this day
            start = date.replace(hour=0, minute=0, second=0, microsecond=0)
            end = start + timedelta(days=1)

            interactions = await self._interaction_repo.query(
                user_id,
                filters=[
                    ("timestamp", ">=", start),
                    ("timestamp", "<", end),
                ],
                limit=1000,
            )

            reviews = len(interactions)
            time_spent = sum(i.time_spent for i in interactions) / 60.0  # seconds → minutes

            activities.append(
                StudyActivity(
                    date=date_str,
                    reviews=reviews,
                    time_spent_minutes=round(time_spent, 1),
                )
            )

        return activities

    async def _compute_total_time(self, user_id: str) -> float:
        """Compute total time spent studying (minutes)."""
        interactions = await self._interaction_repo.query(user_id, limit=5000)
        total_seconds = sum(i.time_spent for i in interactions)
        return round(total_seconds / 60.0, 1)

    async def _compute_achievements(
        self,
        user_id: str,
        note_count: int,
        short_count: int,
        concept_count: int,
        streak: StreakResponse,
        mastery: MasteryDistribution,
    ) -> list[Achievement]:
        """Check achievement milestones."""
        achievements = []

        checks = {
            "first_note": note_count >= 1,
            "ten_notes": note_count >= 10,
            "first_review": mastery.total > 0 and (mastery.learning + mastery.review + mastery.relearning) > 0,
            "streak_7": streak.current >= 7 or streak.longest >= 7,
            "streak_30": streak.current >= 30 or streak.longest >= 30,
            "shorts_50": short_count >= 50,
            "shorts_100": short_count >= 100,
            "concepts_25": concept_count >= 25,
            "mastery_first": mastery.review > 0,
        }

        for ach_id, ach_name, ach_desc in _ACHIEVEMENTS:
            unlocked = checks.get(ach_id, False)
            achievements.append(
                Achievement(
                    id=ach_id,
                    name=ach_name,
                    description=ach_desc,
                    unlocked=unlocked,
                )
            )

        return achievements

    @staticmethod
    def _state_to_mastery(state: str) -> float:
        """Convert FSRS state to a 0-1 mastery score."""
        return {
            "new": 0.0,
            "learning": 0.3,
            "review": 0.8,
            "relearning": 0.5,
        }.get(state.lower(), 0.0)
