"""
Firebase Auth middleware for FastAPI.
Ref: PLAN.md Section 0.1 Rule 5 (Auth Required), Section 5.6 (Rate Limiting)

All endpoints require a valid Firebase ID token in the Authorization header
except /health. WebSocket endpoints receive the token via query param.
"""

import logging
from datetime import date
from fastapi import Depends, HTTPException, Request
from firebase_admin import auth as firebase_auth

from models.schemas import AuthenticatedUser
from services.firestore_service import FirestoreService

logger = logging.getLogger(__name__)
firestore = FirestoreService()


async def get_current_user(request: Request) -> AuthenticatedUser:
    """Extract and verify Firebase ID token from Authorization header."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")

    token = auth_header.split("Bearer ")[1]
    return await _verify_token(token)


async def verify_ws_token(token: str) -> AuthenticatedUser:
    """Verify Firebase ID token for WebSocket connections (token via query param)."""
    if not token:
        raise HTTPException(status_code=401, detail="Missing authentication token")
    return await _verify_token(token)


async def _verify_token(token: str) -> AuthenticatedUser:
    """Verify Firebase ID token and return authenticated user."""
    try:
        decoded = firebase_auth.verify_id_token(token)
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired")
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception:
        logger.error("auth_error", extra={"error_type": "token_verification_failed"})
        raise HTTPException(status_code=401, detail="Authentication failed")

    uid = decoded["uid"]

    # Fetch user profile and subscription from Firestore
    profile = await firestore.get_user_profile(uid)
    about_me = await firestore.get_about_me(uid)
    subscription = await firestore.get_subscription(uid)

    return AuthenticatedUser(
        uid=uid,
        email=decoded.get("email", ""),
        name=decoded.get("name", profile.get("name", "")),
        photo_url=decoded.get("picture", profile.get("photoUrl")),
        about_me=about_me,
        plan=subscription.get("plan", "free"),
    )


async def check_rate_limit(user: AuthenticatedUser = Depends(get_current_user)) -> AuthenticatedUser:
    """
    Check free-tier rate limit: 10 messages/day.
    Ref: PLAN.md Section 3.2, Section 5.6 Rate Limiting
    """
    if user.plan == "pro":
        return user

    today = date.today().isoformat()
    count = await firestore.get_daily_message_count(user.uid, today)
    if count >= 10:
        raise HTTPException(
            status_code=429,
            detail="Daily limit reached. Upgrade to Pro for unlimited messages."
        )
    return user
