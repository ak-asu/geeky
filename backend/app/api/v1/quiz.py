"""Quiz and spaced repetition review API routes.

Covers quiz generation, grading, and FSRS-based review sessions.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.middleware.auth import CurrentUserId
from app.api.middleware.rate_limit import CheckRateLimit
from app.dependencies import (
    get_feature_flags,
    get_quiz_generator,
    get_quiz_grader,
    get_review_manager,
)
from app.models.quiz import QuizGenerateRequest, QuizGradeRequest, ReviewSubmitRequest

router = APIRouter(prefix="/quiz", tags=["quiz"])


# --- Quiz Generation ---


@router.post("/generate")
async def generate_quiz(
    _rate_limit: CheckRateLimit,
    user_id: CurrentUserId,
    body: QuizGenerateRequest,
    generator=Depends(get_quiz_generator),
    flags=Depends(get_feature_flags),
) -> dict:
    """Generate a quiz from Shorts, topic, or module (AL-04)."""
    if not await flags.is_enabled("quiz_generation_enabled", default=True):
        raise HTTPException(status_code=503, detail="Quiz generation is temporarily disabled")
    questions = await generator.generate(
        user_id,
        short_ids=body.short_ids,
        topic=body.topic,
        question_types=body.types,
        count=body.count,
    )
    return {
        "data": {
            "questions": [q.model_dump(mode="json", by_alias=True) for q in questions],
            "count": len(questions),
        }
    }


@router.post("/submit")
async def submit_quiz(
    _rate_limit: CheckRateLimit,
    user_id: CurrentUserId,
    body: QuizGradeRequest,
    grader=Depends(get_quiz_grader),
) -> dict:
    """Submit quiz answers, grade them, update BKT concept mastery, and record results."""
    result = await grader.grade_and_save(user_id, body)
    return {"data": result}


# --- Spaced Repetition Review ---


@router.get("/review/due")
async def get_due_cards(
    user_id: CurrentUserId,
    limit: int = Query(default=20, ge=1, le=50),
    review_manager=Depends(get_review_manager),
) -> dict:
    """Get FSRS-scheduled due review cards (AL-01)."""
    session = await review_manager.get_due_cards(user_id, limit=limit)
    return {
        "data": {
            "cards": session.cards,
            "totalDue": session.total_due,
            "newCount": session.new_count,
            "reviewCount": session.review_count,
        }
    }


@router.post("/review/{review_state_id}")
async def submit_review(
    _rate_limit: CheckRateLimit,
    review_state_id: str,
    user_id: CurrentUserId,
    body: ReviewSubmitRequest,
    review_manager=Depends(get_review_manager),
) -> dict:
    """Submit a spaced repetition review result (AL-01)."""
    response = await review_manager.submit_review(user_id, review_state_id, body.rating)
    return {
        "data": {
            "cardId": response.card_id,
            "nextDue": response.next_due.isoformat() if response.next_due else None,
            "newState": response.new_state,
            "intervalDays": response.interval_days,
            "stability": response.stability,
            "difficulty": response.difficulty,
        }
    }
