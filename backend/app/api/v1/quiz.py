from __future__ import annotations

from fastapi import APIRouter

from app.api.middleware.auth import CurrentUserId

router = APIRouter(prefix="/quiz", tags=["quiz"])


@router.post("/generate")
async def generate_quiz(user_id: CurrentUserId) -> dict:
    """Generate a quiz from user notes or a specific module."""
    return {"message": "Not implemented yet"}


@router.post("/grade")
async def grade_answers(user_id: CurrentUserId) -> dict:
    """Grade submitted quiz answers."""
    return {"message": "Not implemented yet"}


@router.get("/review/due")
async def get_due_cards(user_id: CurrentUserId) -> dict:
    """Get FSRS due flashcards for spaced repetition review."""
    return {"message": "Not implemented yet"}


@router.post("/review/{card_id}")
async def submit_review(card_id: str, user_id: CurrentUserId) -> dict:
    """Submit a spaced repetition review result for a card."""
    return {"message": "Not implemented yet"}
