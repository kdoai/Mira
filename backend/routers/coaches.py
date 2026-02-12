"""
Coach management API — creation, sharing, browsing.
Ref: PLAN.md Section 3.5, Section 5.6 (POST /coaches/create, GET /coaches/shared)

Endpoints:
  POST /coaches/create — create a custom coach
  GET  /coaches/shared/{shareCode} — get shared coach info
  POST /coaches/add/{shareCode} — add shared coach to user's library
"""

import logging
import secrets
import string
import uuid

from fastapi import APIRouter, Depends, HTTPException

from middleware.auth import get_current_user
from models.schemas import (
    AuthenticatedUser,
    CreateCoachRequest,
    CoachResponse,
    SharedCoachResponse,
)
from services.firestore_service import FirestoreService
from services.coach_prompts import generate_custom_coach_prompt

logger = logging.getLogger(__name__)
router = APIRouter()
firestore = FirestoreService()


def generate_share_code() -> str:
    """
    Generate unique 8-char share code (A-Z, 0-9).
    Ref: PLAN.md Section 3.5
    """
    charset = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(charset) for _ in range(8))


@router.post("/create", response_model=CoachResponse, status_code=201)
async def create_coach(
    request: CreateCoachRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Create a custom coach.
    Ref: PLAN.md Section 3.5, Section 8.4
    """
    if user.plan == "free":
        raise HTTPException(
            status_code=403,
            detail="Custom coach creation is a Pro feature."
        )

    coach_id = str(uuid.uuid4())

    # Generate unique share code with collision check
    share_code = generate_share_code()
    while await firestore.share_code_exists(share_code):
        share_code = generate_share_code()

    # Generate system prompt from user inputs
    system_prompt = generate_custom_coach_prompt(
        name=request.name,
        focus=request.focus,
        style=request.style,
    )

    coach_data = {
        "name": request.name,
        "focus": request.focus,
        "style": request.style,
        "systemPrompt": system_prompt,
        "creatorId": user.uid,
        "creatorName": user.name,
        "shareCode": share_code,
        "isBuiltIn": False,
        "usageCount": 0,
        "createdAt": __import__("datetime").datetime.utcnow().isoformat(),
    }

    await firestore.create_coach(coach_id, coach_data)

    return CoachResponse(
        coach_id=coach_id,
        name=request.name,
        focus=request.focus,
        style=request.style,
        share_code=share_code,
        is_built_in=False,
        creator_name=user.name,
        usage_count=0,
    )


@router.get("/mine")
async def get_my_coaches(
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Get user's custom coaches for client-side persistence."""
    coaches = await firestore.get_user_coaches(user.uid)
    return {"coaches": [
        {
            "coach_id": c.get("coach_id", ""),
            "name": c.get("name", ""),
            "focus": c.get("focus", ""),
            "style": c.get("style", "warm"),
            "share_code": c.get("shareCode", ""),
            "is_built_in": False,
            "creator_name": c.get("creatorName", ""),
            "usage_count": c.get("usageCount", 0),
        }
        for c in coaches
    ]}


@router.get("/shared/{share_code}", response_model=SharedCoachResponse)
async def get_shared_coach(
    share_code: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Get info about a shared coach by share code.
    Ref: PLAN.md Section 5.6 (GET /coaches/shared/{shareCode})
    """
    coach = await firestore.get_coach_by_share_code(share_code.upper())
    if not coach:
        raise HTTPException(status_code=404, detail="Coach not found")

    return SharedCoachResponse(
        coach_id=coach["coach_id"],
        name=coach.get("name", ""),
        focus=coach.get("focus", ""),
        style=coach.get("style", ""),
        creator_name=coach.get("creatorName", "Anonymous"),
        usage_count=coach.get("usageCount", 0),
    )


@router.post("/add/{share_code}")
async def add_shared_coach(
    share_code: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Add a shared coach to user's library.
    Ref: PLAN.md Section 5.6 (POST /coaches/add/{shareCode})
    """
    if user.plan == "free":
        raise HTTPException(
            status_code=403,
            detail="Adding custom coaches is a Pro feature."
        )

    coach = await firestore.get_coach_by_share_code(share_code.upper())
    if not coach:
        raise HTTPException(status_code=404, detail="Coach not found")

    coach_id = coach["coach_id"]

    # Don't add your own coach
    if coach.get("creatorId") == user.uid:
        return {"success": True, "coach_id": coach_id, "message": "This is your own coach"}

    # Check if already in library
    already_added = await firestore.is_coach_in_library(user.uid, coach_id)
    if not already_added:
        # Save to user's library for persistence across restarts
        await firestore.add_coach_to_library(user.uid, coach_id)
        # Increment usage count
        await firestore.increment_coach_usage(coach_id)

    return {"success": True, "coach_id": coach_id}
