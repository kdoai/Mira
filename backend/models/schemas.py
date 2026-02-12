"""
Pydantic models for request/response validation.
Ref: PLAN.md Section 5.6 (API Contracts), Section 6 (Firestore Schema)
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# === Chat ===

class ChatMessageItem(BaseModel):
    role: str = Field(..., pattern="^(user|model)$")
    content: str = Field(..., max_length=2000)


class ChatRequest(BaseModel):
    coach_id: str
    conversation_id: str
    message: str = Field(..., max_length=2000)
    history: list[ChatMessageItem] = []


# === Coach ===

class CreateCoachRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=30)
    focus: str = Field(..., min_length=10, max_length=200)
    style: str = Field(..., pattern="^(warm|direct|playful)$")


class CoachResponse(BaseModel):
    coach_id: str
    name: str
    focus: str
    style: str
    share_code: str
    is_built_in: bool = False
    creator_name: Optional[str] = None
    usage_count: int = 0


class SharedCoachResponse(BaseModel):
    coach_id: str
    name: str
    focus: str
    style: str
    creator_name: str
    usage_count: int


# === Profile ===

class AboutMeRequest(BaseModel):
    free_text: str = Field(..., max_length=500)


class ProfileResponse(BaseModel):
    name: str
    email: str
    photo_url: Optional[str] = None
    plan: str = "free"
    daily_messages_used: int = 0
    daily_messages_limit: int = 10
    voice_minutes_used: float = 0
    voice_minutes_limit: int = 60
    about_me: str = ""


# === Conversations ===

class ConversationSummary(BaseModel):
    id: str
    coach_id: str
    coach_name: str
    type: str  # "text" | "voice"
    title: str
    last_message_preview: str = ""
    created_at: str
    updated_at: str
    message_count: int = 0
    next_action: str = ""
    action_status: str = "not_started"  # "not_started" | "in_progress" | "done"
    has_report: bool = False
    report_summary: str = ""


class ConversationsResponse(BaseModel):
    conversations: list[ConversationSummary]
    has_more: bool


class MessageItem(BaseModel):
    id: str
    role: str
    content: str
    timestamp: str


class MessagesResponse(BaseModel):
    messages: list[MessageItem]
    has_more: bool


# === Session Report ===

class SessionReport(BaseModel):
    summary: str
    key_insights: list[str]
    action_items: list[str]
    mood_observation: str
    generated_at: str


class ActionStatusUpdateRequest(BaseModel):
    action_status: str = Field(..., pattern="^(not_started|in_progress|done)$")


# === Auth (internal) ===

class AuthenticatedUser(BaseModel):
    uid: str
    email: str
    name: str = ""
    photo_url: Optional[str] = None
    about_me: str = ""
    plan: str = "free"
