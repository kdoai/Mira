"""
User profile API — About Me, profile info, subscription sync.
Ref: PLAN.md Section 5.6 (PUT /profile/about-me, GET /profile)
"""

import logging
import os
from datetime import date

import httpx
from fastapi import APIRouter, Depends, HTTPException

from middleware.auth import get_current_user
from models.schemas import AuthenticatedUser, AboutMeRequest, ProfileResponse
from services.firestore_service import FirestoreService

REVENUECAT_SECRET_KEY = os.environ.get("REVENUECAT_SECRET_KEY", "")

logger = logging.getLogger(__name__)
router = APIRouter()
firestore = FirestoreService()


@router.get("", response_model=ProfileResponse)
async def get_profile(
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Get user profile including subscription status.
    Ref: PLAN.md Section 5.6 (GET /profile)
    """
    subscription = await firestore.get_subscription(user.uid)
    today = date.today().isoformat()
    daily_count = await firestore.get_daily_message_count(user.uid, today)
    voice_usage = await firestore.get_voice_usage(user.uid)

    return ProfileResponse(
        name=user.name,
        email=user.email,
        photo_url=user.photo_url,
        plan=user.plan,
        daily_messages_used=daily_count,
        daily_messages_limit=10,
        voice_minutes_used=round(voice_usage.get("monthlyMinutes", 0), 1),
        voice_minutes_limit=60,
        about_me=user.about_me,
    )


@router.put("/about-me")
async def update_about_me(
    request: AboutMeRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Update About Me free text.
    Ref: PLAN.md Section 5.6 (PUT /profile/about-me)
    """
    await firestore.update_about_me(user.uid, request.free_text)
    return {"success": True}


@router.put("/display-name")
async def update_display_name(
    request: dict,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Update user display name in Firebase Auth."""
    name = request.get("name", "").strip()
    if not name or len(name) > 50:
        raise HTTPException(400, "Name must be 1-50 characters")
    from firebase_admin import auth as fb_auth
    fb_auth.update_user(user.uid, display_name=name)
    return {"success": True, "name": name}


@router.post("/subscription/sync")
async def sync_subscription(
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Verify subscription with RevenueCat server-side, then write to Firestore.
    Called by client after purchase/restore.
    """
    if not REVENUECAT_SECRET_KEY:
        raise HTTPException(status_code=500, detail="Subscription service not configured")

    # Verify with RevenueCat REST API (server-to-server, no client spoofing)
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"https://api.revenuecat.com/v1/subscribers/{user.uid}",
            headers={
                "Authorization": f"Bearer {REVENUECAT_SECRET_KEY}",
                "Content-Type": "application/json",
            },
        )

    if resp.status_code != 200:
        logger.error("revenuecat_verify_failed", extra={
            "user_id": user.uid,
            "status": resp.status_code,
        })
        raise HTTPException(status_code=502, detail="Could not verify subscription")

    subscriber = resp.json().get("subscriber", {})
    entitlements = subscriber.get("entitlements", {})
    pro_ent = entitlements.get("pro", {})
    is_active = pro_ent.get("expires_date") is not None

    plan = "pro" if is_active else "free"
    await firestore.update_subscription(user.uid, plan)

    logger.info("metric:subscription_synced", extra={"user_id": user.uid, "plan": plan})
    return {"success": True, "plan": plan}
