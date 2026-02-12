"""
Session management API — conversations, messages, reports.
Ref: PLAN.md Section 5.6 (GET /conversations, GET /conversations/{id}/messages,
     POST /conversations/{id}/report)
Ref: PLAN.md Section 8.6 (Session Report Generation)
"""

import json
import logging
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException

from middleware.auth import get_current_user
from models.schemas import (
    ActionStatusUpdateRequest,
    AuthenticatedUser,
    ConversationsResponse,
    ConversationSummary,
    MessagesResponse,
    MessageItem,
    SessionReport,
)
from services.firestore_service import FirestoreService
from services.gemini_service import generate_content

logger = logging.getLogger(__name__)
router = APIRouter()
firestore = FirestoreService()

# Session report generation prompt
# Ref: research/coach_prompts.md "Session Report Generation Prompt"
REPORT_GENERATION_PROMPT = """Review the following conversation between a user and their AI coach, then generate a structured session report.

## Conversation
{full_conversation}

## Generate the following (in English):

Return your response in this exact JSON format:
{{
  "summary": "2-3 sentence summary of the main topic and what was explored",
  "key_insights": ["insight 1", "insight 2", "insight 3"],
  "action_items": ["action 1", "action 2"],
  "mood_observation": "How the user seemed at start vs end of session"
}}

Keep it concise, warm, and actionable. Write as if you're leaving a note for the user to revisit later. Return ONLY valid JSON."""


@router.get("", response_model=ConversationsResponse)
async def get_conversations(
    limit: int = 20,
    offset: int = 0,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Get user's conversation history.
    Ref: PLAN.md Section 5.6 (GET /conversations)
    """
    conversations, has_more = await firestore.get_conversations(
        user.uid, limit=limit, offset=offset
    )

    return ConversationsResponse(
        conversations=[
            ConversationSummary(**conv) for conv in conversations
        ],
        has_more=has_more,
    )


@router.get("/{conversation_id}/messages", response_model=MessagesResponse)
async def get_messages(
    conversation_id: str,
    limit: int = 50,
    before: str | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Get messages for a conversation.
    Ref: PLAN.md Section 5.6 (GET /conversations/{id}/messages)
    """
    owner_id = await firestore.get_conversation_owner(conversation_id)
    if owner_id is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if owner_id != user.uid:
        raise HTTPException(status_code=403, detail="Forbidden")

    messages = await firestore.get_messages(
        conversation_id, limit=limit + 1, before=before
    )

    has_more = len(messages) > limit
    message_items = [
        MessageItem(
            id=msg["id"],
            role=msg.get("role", "user"),
            content=msg.get("content", ""),
            timestamp=msg.get("timestamp", ""),
        )
        for msg in messages[:limit]
    ]

    return MessagesResponse(messages=message_items, has_more=has_more)


@router.post("/{conversation_id}/report", response_model=SessionReport)
async def generate_report(
    conversation_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Generate a session report from conversation.
    Ref: PLAN.md Section 8.6 (Session Report Generation)

    Trigger conditions (checked client-side):
    - Text: >= 4 messages, triggered on back navigation
    - Voice: auto on session end
    - Manual: user taps "Generate Report" button
    """
    # Ownership check
    owner_id = await firestore.get_conversation_owner(conversation_id)
    if owner_id is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if owner_id != user.uid:
        raise HTTPException(status_code=403, detail="Forbidden")

    # Check if report already exists
    existing = await firestore.get_report(conversation_id)
    if existing:
        return SessionReport(**existing)

    # Get conversation messages
    messages = await firestore.get_messages(conversation_id, limit=100)

    if len(messages) < 4:
        raise HTTPException(
            status_code=400,
            detail="Session too short for a report. At least 4 messages required."
        )

    # Build transcript
    transcript = "\n".join([
        f"{msg.get('role', 'user')}: {msg.get('content', '')}"
        for msg in messages
    ])

    prompt = REPORT_GENERATION_PROMPT.replace("{full_conversation}", transcript)

    try:
        response_text = await generate_content(
            system_prompt="You are a coaching session analyst. Return ONLY valid JSON, no markdown formatting.",
            user_prompt=prompt,
            temperature=0.5,
            max_tokens=1024,
        )

        # Strip markdown code blocks if present (Gemini often wraps JSON)
        cleaned = response_text.strip()
        if cleaned.startswith("```"):
            lines = cleaned.split("\n")
            if lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].strip() == "```":
                lines = lines[:-1]
            cleaned = "\n".join(lines).strip()

        # Parse JSON response
        report_data = json.loads(cleaned)
        report_data["generated_at"] = datetime.utcnow().isoformat()

        # Save to Firestore
        await firestore.save_report(conversation_id, report_data)

        logger.info("metric:report_generated", extra={
            "user_id": user.uid,
            "conversation_id": conversation_id,
        })

        return SessionReport(**report_data)

    except json.JSONDecodeError:
        logger.error("report_parse_error", extra={
            "user_id": user.uid,
            "conversation_id": conversation_id,
        })
        raise HTTPException(
            status_code=500,
            detail="Failed to generate report. Please try again."
        )
    except Exception as e:
        logger.error("report_generation_error", extra={
            "user_id": user.uid,
            "error_type": type(e).__name__,
        })
        raise HTTPException(
            status_code=500,
            detail="Failed to generate report. Please try again."
        )


@router.delete("/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Delete a conversation and its data."""
    owner_id = await firestore.get_conversation_owner(conversation_id)
    if owner_id is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if owner_id != user.uid:
        raise HTTPException(status_code=403, detail="Forbidden")

    await firestore.delete_conversation(conversation_id)
    return {"success": True}


@router.patch("/{conversation_id}/action-status")
async def update_action_status(
    conversation_id: str,
    request: ActionStatusUpdateRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Update action status for a conversation.
    Used by History screen to track follow-through.
    """
    owner_id = await firestore.get_conversation_owner(conversation_id)
    if owner_id is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if owner_id != user.uid:
        raise HTTPException(status_code=403, detail="Forbidden")

    await firestore.update_action_status(conversation_id, request.action_status)

    if request.action_status == "done":
        logger.info("metric:action_completed", extra={
            "user_id": user.uid,
            "conversation_id": conversation_id,
        })

    return {"success": True}
