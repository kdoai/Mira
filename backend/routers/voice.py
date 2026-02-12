"""
Voice WebSocket proxy — Cloud Run to Gemini Live API.
Ref: PLAN.md Section 5.2, 5.3, 5.6 (WS /ws/voice)

Bidirectional audio proxy:
  Client (Flutter) ←WebSocket→ Cloud Run ←WebSocket→ Gemini Live API

Protocol:
  Client → Server:
    {"type": "audio", "data": "<base64 PCM 16kHz mono>"}
    {"type": "end_session"}
  Server → Client:
    {"type": "audio", "data": "<base64 PCM 24kHz mono>"}
    {"type": "transcript", "role": "user"|"assistant", "text": "string"}
    {"type": "ping"}
    {"type": "error", "message": "string"}
    {"type": "session_ended", "duration_minutes": number}
"""

import asyncio
import json
import logging
import time

import websockets
import google.auth
import google.auth.transport.requests
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from middleware.auth import verify_ws_token
from services.firestore_service import FirestoreService
from services.coach_prompts import build_coach_prompt, is_built_in, get_coach_voice
from services.gemini_service import generate_voice_session_title
import config

logger = logging.getLogger(__name__)
router = APIRouter()
firestore = FirestoreService()


async def get_google_access_token() -> str:
    """Get OAuth2 access token for Gemini Live API."""
    creds, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    request = google.auth.transport.requests.Request()
    creds.refresh(request)
    return creds.token


def build_setup_message(system_prompt: str, voice_name: str = "Aoede") -> dict:
    """
    Build Gemini Live setup message.
    Ref: PLAN.md Section 5.3
    """
    return {
        "setup": {
            "model": (
                f"projects/{config.GCP_PROJECT_ID}/locations/{config.GEMINI_VOICE_LOCATION}"
                f"/publishers/google/models/{config.GEMINI_VOICE_MODEL}"
            ),
            "generation_config": {
                "response_modalities": ["AUDIO"],
                "speech_config": {
                    "voice_config": {
                        "prebuilt_voice_config": {"voice_name": voice_name}
                    }
                },
            },
            "system_instruction": {
                "parts": [{"text": system_prompt}]
            },
            "realtime_input_config": {
                "automatic_activity_detection": {
                    "disabled": False,
                    "silence_duration_ms": 1000,
                    "prefix_padding_ms": 300,
                }
            },
            "input_audio_transcription": {},
            "output_audio_transcription": {},
        }
    }


@router.websocket("/ws/voice/{conversation_id}")
async def voice_session(websocket: WebSocket, conversation_id: str):
    await websocket.accept()

    # 1. Auth: token from query param (WebSocket can't use headers)
    # Ref: PLAN.md Section 5.2
    token = websocket.query_params.get("token")
    try:
        user = await verify_ws_token(token)
    except Exception:
        await websocket.send_json({"type": "error", "message": "Authentication failed"})
        await websocket.close()
        return

    # 2. Voice access check — Pro gets 60 min/month, Free gets ONE 5-min trial
    FREE_VOICE_TRIAL_MINUTES = 5

    if user.plan == "free":
        trial_used = await firestore.is_voice_trial_used(user.uid)
        if trial_used:
            await websocket.send_json({
                "type": "error",
                "message": "You've used your free voice session. Upgrade to Pro for unlimited voice coaching.",
            })
            await websocket.close()
            return
        # Mark trial as used immediately (prevent parallel sessions)
        await firestore.mark_voice_trial_used(user.uid)
    else:
        usage = await firestore.get_voice_usage(user.uid)
        if usage.get("monthlyMinutes", 0) >= config.VOICE_MONTHLY_MINUTES_LIMIT:
            await websocket.send_json({
                "type": "error",
                "message": "Monthly voice limit reached (60 minutes). Resets next month.",
            })
            await websocket.close()
            return

    # Determine session time limit based on plan
    session_max_minutes = (
        FREE_VOICE_TRIAL_MINUTES if user.plan == "free"
        else config.VOICE_SESSION_MAX_MINUTES
    )

    # 3. Build coach prompt
    coach_id = websocket.query_params.get("coach_id", "mira")
    custom_prompt = None
    coach_name = coach_id
    if not is_built_in(coach_id):
        coach_data = await firestore.get_coach(coach_id)
        if coach_data:
            custom_prompt = coach_data.get("systemPrompt", "")
            coach_name = coach_data.get("name", coach_id)

    # Add voice mode adjustments to prompt
    # Ref: PLAN.md Section 8.5
    voice_rules = """

## Voice Mode Rules
- Keep responses to 2-3 sentences MAX (under 15 seconds of speech)
- Be more conversational, less structured
- Use natural filler words sparingly ("hmm", "right", "I see")
- Don't use bullet points or numbered lists (speak naturally)
- React to emotional tone, not just words"""

    system_prompt = build_coach_prompt(
        coach_id, user.about_me, custom_prompt,
        message_count=0, is_resumed=False,
    ) + voice_rules
    voice_name = get_coach_voice(coach_id)
    logger.info(f"voice_session: coach={coach_id} voice={voice_name}")

    # 4. Ensure conversation exists + ownership check
    if await firestore.conversation_exists(conversation_id):
        owner_id = await firestore.get_conversation_owner(conversation_id)
        if owner_id is not None and owner_id != user.uid:
            await websocket.send_json({"type": "error", "message": "Forbidden"})
            await websocket.close()
            return
    else:
        await firestore.create_conversation(
            conversation_id=conversation_id,
            user_id=user.uid,
            coach_id=coach_id,
            coach_name=coach_name,
            conv_type="voice",
        )
        logger.info("metric:session_started", extra={
            "user_id": user.uid,
            "coach_id": coach_id,
            "conversation_id": conversation_id,
            "type": "voice",
        })

    # 5. Connect to Gemini Live API
    try:
        access_token = await get_google_access_token()
        gemini_url = (
            f"wss://{config.GEMINI_VOICE_LOCATION}-aiplatform.googleapis.com/ws/"
            "google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent"
        )
        gemini_ws = await websockets.connect(
            gemini_url,
            extra_headers={"Authorization": f"Bearer {access_token}"},
        )
    except Exception as e:
        logger.error(f"gemini_live_connect_error: {type(e).__name__}: {e}")
        await websocket.send_json({"type": "error", "message": f"Failed to connect to voice service: {type(e).__name__}"})
        await websocket.close()
        return

    # 6. Send setup message and wait for setupComplete
    setup_msg = build_setup_message(system_prompt, voice_name=voice_name)
    await gemini_ws.send(json.dumps(setup_msg))

    try:
        setup_response = await asyncio.wait_for(gemini_ws.recv(), timeout=10)
        setup_data = json.loads(setup_response)
        if "setupComplete" in setup_data:
            logger.info("gemini_setup_complete: ready for audio")
        else:
            logger.warning(f"unexpected_setup_response: {json.dumps(setup_data)[:500]}")
    except asyncio.TimeoutError:
        logger.error("gemini_setup_timeout: no setupComplete in 10s")
        await websocket.send_json({"type": "error", "message": "Voice service timed out during setup"})
        await websocket.close()
        await gemini_ws.close()
        return

    # 7. Bidirectional proxy with keep-alive
    session_start = time.time()
    # Ordered list of (role, text) tuples — preserves turn order for consolidation
    transcript_turns: list[tuple[str, str]] = []
    session_active = True

    async def client_to_gemini():
        """Forward audio from Flutter client to Gemini Live."""
        nonlocal session_active
        audio_chunks_received = 0
        try:
            async for msg in websocket.iter_text():
                if not session_active:
                    break
                data = json.loads(msg)
                if data["type"] == "audio":
                    audio_chunks_received += 1
                    if audio_chunks_received <= 3:
                        logger.info(f"client_audio_chunk #{audio_chunks_received} size={len(data['data'])}")
                    await gemini_ws.send(json.dumps({
                        "realtime_input": {
                            "media_chunks": [{
                                "data": data["data"],
                                "mime_type": "audio/pcm",
                            }]
                        }
                    }))
                elif data["type"] == "end_session":
                    session_active = False
                    break
        except WebSocketDisconnect:
            session_active = False
        except Exception as e:
            logger.error("client_to_gemini_error", extra={
                "user_id": user.uid,
                "error_type": type(e).__name__,
            })
            session_active = False

    async def gemini_to_client():
        """Forward audio and transcripts from Gemini Live to Flutter client."""
        nonlocal session_active
        audio_chunks_sent = 0
        try:
            async for msg in gemini_ws:
                if not session_active:
                    break
                data = json.loads(msg)

                # Log all top-level keys for debugging
                keys = list(data.keys())
                if keys != ["serverContent"]:
                    logger.info(f"gemini_msg_keys: {keys}")

                server_content = data.get("serverContent", {})

                # Forward audio response
                if "modelTurn" in server_content:
                    parts = server_content["modelTurn"].get("parts", [])
                    for part in parts:
                        if "inlineData" in part:
                            audio_chunks_sent += 1
                            audio_data = part["inlineData"]["data"]
                            if audio_chunks_sent <= 5:
                                logger.info(f"forwarding_audio_chunk #{audio_chunks_sent} size={len(audio_data)}")
                            await websocket.send_json({
                                "type": "audio",
                                "data": audio_data,
                            })

                # Forward transcripts and collect in order
                if "inputTranscription" in server_content:
                    text = server_content["inputTranscription"].get("text", "")
                    if text:
                        transcript_turns.append(("user", text))
                        await websocket.send_json({
                            "type": "transcript",
                            "role": "user",
                            "text": text,
                        })

                if "outputTranscription" in server_content:
                    text = server_content["outputTranscription"].get("text", "")
                    if text:
                        transcript_turns.append(("assistant", text))
                        await websocket.send_json({
                            "type": "transcript",
                            "role": "assistant",
                            "text": text,
                        })

                # Forward turn complete signal (AI finished speaking)
                if server_content.get("turnComplete"):
                    logger.info("turn_complete received from Gemini")
                    await websocket.send_json({
                        "type": "turn_complete",
                    })

                # Check session time limit
                elapsed = (time.time() - session_start) / 60
                if elapsed >= session_max_minutes:
                    await websocket.send_json({
                        "type": "error",
                        "message": (
                            "Free voice session complete (5 minutes). Upgrade to Pro for unlimited sessions."
                            if user.plan == "free"
                            else "Session time limit reached (30 minutes)."
                        ),
                    })
                    session_active = False
                    break

                # Time warnings
                remaining = session_max_minutes - elapsed
                if user.plan == "free" and 0.9 <= remaining <= 1.1:
                    await websocket.send_json({
                        "type": "transcript",
                        "role": "assistant",
                        "text": "[1 minute remaining in your free session]",
                    })
                elif user.plan == "pro" and 4.9 <= remaining <= 5.1:
                    await websocket.send_json({
                        "type": "transcript",
                        "role": "assistant",
                        "text": "[5 minutes remaining in session]",
                    })

        except websockets.exceptions.ConnectionClosed:
            session_active = False
        except Exception as e:
            logger.error("gemini_to_client_error", extra={
                "user_id": user.uid,
                "error_type": type(e).__name__,
            })
            session_active = False

    async def keep_alive():
        """Send keep-alive ping every 30s to prevent WebSocket timeout."""
        while session_active:
            await asyncio.sleep(30)
            try:
                await websocket.send_json({"type": "ping"})
            except Exception:
                break

    try:
        await asyncio.gather(
            client_to_gemini(),
            gemini_to_client(),
            keep_alive(),
        )
    except BaseException as e:
        logger.info(f"voice_gather_ended: {type(e).__name__}")

    # Save transcripts + record usage (outside try/finally to avoid cancellation issues)
    try:
        duration_min = (time.time() - session_start) / 60
        logger.info(f"voice_session_end: duration={round(duration_min, 1)}min, "
                     f"transcript_chunks={len(transcript_turns)}")

        # Consolidate transcript chunks into turn-based messages.
        # Adjacent chunks with the same role are joined into one message.
        consolidated: list[tuple[str, str]] = []
        for role, text in transcript_turns:
            if consolidated and consolidated[-1][0] == role:
                consolidated[-1] = (role, consolidated[-1][1] + text)
            else:
                consolidated.append((role, text))

        logger.info(f"voice_transcripts_consolidated: {len(transcript_turns)} chunks -> {len(consolidated)} messages")

        # Save consolidated messages in conversation order
        for role, text in consolidated:
            if text.strip():
                await firestore.add_message(conversation_id, role, text)

        logger.info(f"voice_transcripts_saved: {len(consolidated)} messages")

        # Auto-generate title from full conversation transcript
        if consolidated:
            try:
                title = await generate_voice_session_title(consolidated)
                await firestore.update_conversation_title(conversation_id, title)
                logger.info(f"voice_title_generated: {title}")
            except Exception as e:
                logger.error(f"voice_title_error: {type(e).__name__}: {e}")

        # Update voice usage
        await firestore.update_voice_usage(
            user.uid, duration_min, conversation_id
        )
    except BaseException as e:
        logger.error(f"voice_save_error: {type(e).__name__}: {e}")

    # Send session ended + clean up
    try:
        await websocket.send_json({
            "type": "session_ended",
            "duration_minutes": round(duration_min, 1),
        })
    except Exception:
        pass
    try:
        await gemini_ws.close()
    except Exception:
        pass
