"""
Text chat API with SSE streaming.
Ref: PLAN.md Section 5.1, Section 5.6 (POST /chat/send)

SSE Events:
  event: message → data: {"text": "chunk"}
  event: error   → data: {"error": "message"}
  event: done    → data: ""
"""

import json
import logging

from fastapi import APIRouter, Depends, HTTPException
from sse_starlette.sse import EventSourceResponse

from middleware.auth import get_current_user, check_rate_limit
from models.schemas import ChatRequest, AuthenticatedUser
from services.gemini_service import stream_chat_response, generate_conversation_title
from services.coach_prompts import build_coach_prompt, is_built_in, get_coach_name
from services.firestore_service import FirestoreService

logger = logging.getLogger(__name__)
router = APIRouter()
firestore = FirestoreService()


@router.post("/send")
async def chat_send(
    request: ChatRequest,
    user: AuthenticatedUser = Depends(check_rate_limit),
):
    """
    Send a message and receive a streaming SSE response.
    Ref: PLAN.md Section 5.1, Section 5.6
    """
    # Pro coach enforcement — free users can only use 'mira'
    PRO_COACHES = {'atlas', 'lyra', 'sol', 'ember'}
    if user.plan != "pro":
        if request.coach_id in PRO_COACHES or not is_built_in(request.coach_id):
            raise HTTPException(
                status_code=403,
                detail="This coach requires a Pro subscription.",
            )

    # Get coach prompt
    custom_prompt = None
    coach_name = get_coach_name(request.coach_id)
    if not is_built_in(request.coach_id):
        coach_data = await firestore.get_coach(request.coach_id)
        if not coach_data:
            return EventSourceResponse(
                _error_generator("Coach not found"),
                media_type="text/event-stream",
            )
        custom_prompt = coach_data.get("systemPrompt", "")
        coach_name = coach_data.get("name", request.coach_id)

    # Determine session stage context
    message_count = len(request.history)
    is_resumed = False
    previous_action = ""

    if await firestore.conversation_exists(request.conversation_id):
        # Ownership check — prevent writing to another user's conversation
        owner_id = await firestore.get_conversation_owner(request.conversation_id)
        if owner_id is not None and owner_id != user.uid:
            raise HTTPException(status_code=403, detail="Forbidden")
        is_resumed = message_count > 0
        # Fetch previous action for follow-up enforcement
        if is_resumed:
            report = await firestore.get_report(request.conversation_id)
            if report:
                action_items = report.get("action_items", [])
                if action_items:
                    previous_action = action_items[0]

    system_prompt = build_coach_prompt(
        request.coach_id, user.about_me, custom_prompt,
        message_count=message_count,
        is_resumed=is_resumed,
        previous_action=previous_action,
    )

    # Ensure conversation exists in Firestore
    if not await firestore.conversation_exists(request.conversation_id):
        await firestore.create_conversation(
            conversation_id=request.conversation_id,
            user_id=user.uid,
            coach_id=request.coach_id,
            coach_name=coach_name,
            conv_type="text",
        )
        logger.info("metric:session_started", extra={
            "user_id": user.uid,
            "coach_id": request.coach_id,
            "conversation_id": request.conversation_id,
            "type": "text",
        })

    # Save user message to Firestore
    await firestore.add_message(
        request.conversation_id, "user", request.message
    )

    # Increment daily message count for free users
    if user.plan == "free":
        await firestore.increment_daily_message_count(user.uid)

    # Build history for Gemini
    history = [{"role": m.role, "content": m.content} for m in request.history]

    async def event_generator():
        full_response = ""
        chunk_count = 0
        try:
            logger.info(f"chat_stream_start: coach={request.coach_id} user={user.uid}")
            async for chunk in stream_chat_response(
                system_prompt=system_prompt,
                history=history,
                user_message=request.message,
            ):
                chunk_count += 1
                full_response += chunk
                if chunk_count == 1:
                    logger.info(f"chat_first_chunk: len={len(chunk)}")
                yield {"event": "message", "data": json.dumps({"text": chunk})}
            logger.info(f"chat_stream_done: chunks={chunk_count} total_len={len(full_response)}")
        except Exception as e:
            logger.error(f"chat_stream_error: {type(e).__name__}: {e}")
            yield {"event": "error", "data": json.dumps({"error": "I'm having trouble thinking right now. Try again in a moment."})}
        finally:
            # Save assistant response to Firestore
            if full_response:
                await firestore.add_message(
                    request.conversation_id, "assistant", full_response
                )

                # Auto-generate title after first exchange (>= 2 messages)
                conv_messages = await firestore.get_messages(
                    request.conversation_id, limit=3
                )
                if len(conv_messages) == 2:
                    title = await generate_conversation_title(request.message)
                    await firestore.update_conversation_title(
                        request.conversation_id, title
                    )

            yield {"event": "done", "data": ""}

    return EventSourceResponse(
        event_generator(),
        media_type="text/event-stream",
    )


async def _error_generator(message: str):
    yield {"event": "error", "data": json.dumps({"error": message})}
    yield {"event": "done", "data": ""}
