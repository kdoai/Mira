"""
Gemini API wrapper service.
Ref: PLAN.md Section 5.1 (Text Chat), Section 8.6 (Session Reports)

Uses direct genai.Client API — NOT ADK.
Ref: PLAN.md Section 3.1 decision rationale.
"""

import json
import logging
from typing import AsyncGenerator

from google import genai
from google.genai import types

import config

logger = logging.getLogger(__name__)

# Initialize client (config.py sets environment variables before this import)
client = genai.Client(
    vertexai=True,
    project=config.GCP_PROJECT_ID,
    location=config.GEMINI_TEXT_LOCATION,
)

# Safety settings — disable all for coaching conversations
SAFETY_SETTINGS = [
    types.SafetySetting(category=cat, threshold="OFF")
    for cat in [
        "HARM_CATEGORY_HATE_SPEECH",
        "HARM_CATEGORY_DANGEROUS_CONTENT",
        "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        "HARM_CATEGORY_HARASSMENT",
    ]
]


async def stream_chat_response(
    system_prompt: str,
    history: list[dict],
    user_message: str,
) -> AsyncGenerator[str, None]:
    """
    Stream text chat response from Gemini 3 Flash Preview.
    Ref: PLAN.md Section 5.1

    Uses system_instruction field (NOT first message in contents).
    Yields text chunks as they arrive.
    """
    system_instruction = types.Content(
        parts=[types.Part(text=system_prompt)]
    )

    contents = []
    for msg in history:
        contents.append(types.Content(
            role=msg["role"],
            parts=[types.Part(text=msg["content"])],
        ))
    contents.append(types.Content(
        role="user",
        parts=[types.Part(text=user_message)],
    ))

    try:
        response = await client.aio.models.generate_content_stream(
            model=config.GEMINI_TEXT_MODEL,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.6,
                top_p=0.95,
                max_output_tokens=1024,
                safety_settings=SAFETY_SETTINGS,
            ),
        )
        async for chunk in response:
            if chunk.text:
                yield chunk.text
    except Exception as e:
        logger.error(f"gemini_stream_error: {type(e).__name__}: {e}")
        raise


async def generate_content(
    system_prompt: str,
    user_prompt: str,
    temperature: float = 0.5,
    max_tokens: int = 1024,
) -> str:
    """
    Generate non-streaming content (used for reports, title generation).
    Ref: PLAN.md Section 8.6
    """
    try:
        response = await client.aio.models.generate_content(
            model=config.GEMINI_TEXT_MODEL,
            contents=[
                types.Content(role="user", parts=[types.Part(text=user_prompt)])
            ],
            config=types.GenerateContentConfig(
                system_instruction=types.Content(
                    parts=[types.Part(text=system_prompt)]
                ),
                temperature=temperature,
                max_output_tokens=max_tokens,
                safety_settings=SAFETY_SETTINGS,
            ),
        )
        return response.text or ""
    except Exception as e:
        logger.error("gemini_generate_error", extra={
            "error_type": type(e).__name__,
        })
        raise


async def generate_conversation_title(first_message: str) -> str:
    """
    Generate a 3-6 word conversation title from the first user message.
    Ref: PLAN.md Section 8.6
    """
    try:
        title = await generate_content(
            system_prompt="You generate short conversation titles.",
            user_prompt=f"Generate a concise 3-6 word title for a coaching conversation that starts with this message. Return ONLY the title, nothing else:\n\n\"{first_message}\"",
            temperature=0.3,
            max_tokens=20,
        )
        return title.strip().strip('"')[:50]
    except Exception:
        return "New conversation"


async def generate_voice_session_title(
    transcripts: list[tuple[str, str]],
) -> str:
    """
    Generate a content-rich title from the full voice session transcript.
    Uses the entire conversation for better context than just the first message.
    """
    # Build a brief transcript (limit to ~800 chars to keep token usage low)
    lines = []
    total = 0
    for role, text in transcripts:
        label = "User" if role == "user" else "Coach"
        line = f"{label}: {text}"
        if total + len(line) > 800:
            break
        lines.append(line)
        total += len(line)

    if not lines:
        return "New conversation"

    transcript_text = "\n".join(lines)

    try:
        title = await generate_content(
            system_prompt="You generate short conversation titles.",
            user_prompt=(
                "Generate a concise 3-6 word title that captures the main topic "
                "of this coaching conversation. Return ONLY the title, nothing else.\n\n"
                f"{transcript_text}"
            ),
            temperature=0.3,
            max_tokens=20,
        )
        return title.strip().strip('"')[:50]
    except Exception:
        return "New conversation"
