"""Subscription Pydantic schemas and entitlement definitions."""
from __future__ import annotations

from pydantic import Field

from app.models.common import GeekyBaseModel


class SubscriptionEntitlements(GeekyBaseModel):
    """Defines the capabilities and limits for a subscription tier."""

    max_notes: int = Field(alias="maxNotes", description="-1 means unlimited")
    max_sources: int = Field(alias="maxSources", description="-1 means unlimited")
    rag_queries_per_day: int = Field(alias="ragQueriesPerDay", description="-1 means unlimited")
    advanced_analytics: bool = Field(alias="advancedAnalytics")
    priority_processing: bool = Field(alias="priorityProcessing")


# Single source of truth for subscription tier entitlements.
# Update this dict (not route files) when changing tier limits.
ENTITLEMENTS: dict[str, SubscriptionEntitlements] = {
    "free": SubscriptionEntitlements(
        maxNotes=50,
        maxSources=3,
        ragQueriesPerDay=10,
        advancedAnalytics=False,
        priorityProcessing=False,
    ),
    "premium": SubscriptionEntitlements(
        maxNotes=-1,
        maxSources=-1,
        ragQueriesPerDay=-1,
        advancedAnalytics=True,
        priorityProcessing=True,
    ),
}
