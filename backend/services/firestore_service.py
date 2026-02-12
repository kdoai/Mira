"""
Firestore CRUD service.
Ref: PLAN.md Section 6 (Firestore Schema), Section 6.1 (Security & Access Patterns)

Principle: Server (admin SDK) handles all writes except About Me.
Client is READ-ONLY for most data.
"""

import logging
from datetime import datetime, date
from typing import Optional
from firebase_admin import firestore as fb_firestore
from google.cloud.firestore_v1 import AsyncClient

logger = logging.getLogger(__name__)


class FirestoreService:
    def __init__(self):
        self._db: Optional[AsyncClient] = None

    @property
    def db(self) -> AsyncClient:
        if self._db is None:
            self._db = fb_firestore.client()
        return self._db

    # === User Profile ===

    async def get_user_profile(self, uid: str) -> dict:
        doc = self.db.collection("users").document(uid).collection("profile").document("data")
        snapshot = doc.get()
        if snapshot.exists:
            return snapshot.to_dict()
        return {}

    async def create_or_update_profile(self, uid: str, data: dict) -> None:
        doc = self.db.collection("users").document(uid).collection("profile").document("data")
        doc.set(data, merge=True)

    # === About Me ===

    async def get_about_me(self, uid: str) -> str:
        doc = self.db.collection("users").document(uid).collection("about_me").document("data")
        snapshot = doc.get()
        if snapshot.exists:
            return snapshot.to_dict().get("freeText", "")
        return ""

    async def update_about_me(self, uid: str, free_text: str) -> None:
        doc = self.db.collection("users").document(uid).collection("about_me").document("data")
        doc.set({"freeText": free_text, "updatedAt": datetime.utcnow().isoformat()})

    # === Subscription ===

    async def get_subscription(self, uid: str) -> dict:
        doc = self.db.collection("users").document(uid).collection("subscription").document("data")
        snapshot = doc.get()
        if snapshot.exists:
            return snapshot.to_dict()
        return {"plan": "free"}

    # === Rate Limiting ===

    async def get_daily_message_count(self, uid: str, today: str) -> int:
        doc = self.db.collection("users").document(uid).collection("subscription").document("data")
        snapshot = doc.get()
        if not snapshot.exists:
            return 0
        data = snapshot.to_dict()
        if data.get("lastMessageDate") != today:
            return 0
        return data.get("dailyMessageCount", 0)

    async def increment_daily_message_count(self, uid: str) -> None:
        today = date.today().isoformat()
        doc = self.db.collection("users").document(uid).collection("subscription").document("data")
        snapshot = doc.get()

        if snapshot.exists:
            data = snapshot.to_dict()
            if data.get("lastMessageDate") == today:
                count = data.get("dailyMessageCount", 0) + 1
            else:
                count = 1
        else:
            count = 1

        doc.set({
            "dailyMessageCount": count,
            "lastMessageDate": today,
        }, merge=True)

    # === Conversations ===

    async def create_conversation(self, conversation_id: str, user_id: str,
                                   coach_id: str, coach_name: str,
                                   conv_type: str = "text") -> None:
        now = datetime.utcnow().isoformat()
        doc = self.db.collection("conversations").document(conversation_id)
        doc.set({
            "metadata": {
                "userId": user_id,
                "coachId": coach_id,
                "coachName": coach_name,
                "type": conv_type,
                "title": "New conversation",
                "createdAt": now,
                "updatedAt": now,
                "messageCount": 0,
                "lastMessagePreview": "",
                "actionStatus": "not_started",
            }
        })

    async def conversation_exists(self, conversation_id: str) -> bool:
        doc = self.db.collection("conversations").document(conversation_id)
        snapshot = doc.get()
        return snapshot.exists

    async def add_message(self, conversation_id: str, role: str, content: str) -> str:
        now = datetime.utcnow().isoformat()
        conv_doc = self.db.collection("conversations").document(conversation_id)
        msg_ref = conv_doc.collection("messages").document()
        msg_ref.set({
            "role": role,
            "content": content,
            "timestamp": now,
        })

        # Update conversation metadata
        preview = content[:100] if content else ""
        conv_snapshot = conv_doc.get()
        if conv_snapshot.exists:
            metadata = conv_snapshot.to_dict().get("metadata", {})
            count = metadata.get("messageCount", 0) + 1
            conv_doc.update({
                "metadata.updatedAt": now,
                "metadata.messageCount": count,
                "metadata.lastMessagePreview": preview,
            })

        return msg_ref.id

    async def get_messages(self, conversation_id: str, limit: int = 50,
                            before: Optional[str] = None) -> list[dict]:
        query = (self.db.collection("conversations")
                 .document(conversation_id)
                 .collection("messages")
                 .order_by("timestamp"))

        results = query.limit(limit).stream()
        messages = []
        for doc in results:
            data = doc.to_dict()
            data["id"] = doc.id
            messages.append(data)
        return messages

    async def get_conversations(self, user_id: str, limit: int = 20,
                                 offset: int = 0) -> tuple[list[dict], bool]:
        query = (self.db.collection("conversations")
                 .where("metadata.userId", "==", user_id)
                 .order_by("metadata.updatedAt", direction=fb_firestore.Query.DESCENDING)
                 .limit(limit + 1)
                 .offset(offset))

        results = list(query.stream())
        has_more = len(results) > limit
        conversations = []
        for doc in results[:limit]:
            data = doc.to_dict()
            metadata = data.get("metadata", {})
            report = data.get("report", {}) or {}
            action_items = report.get("action_items", []) or []
            conversations.append({
                "id": doc.id,
                "coach_id": metadata.get("coachId", ""),
                "coach_name": metadata.get("coachName", ""),
                "type": metadata.get("type", "text"),
                "title": metadata.get("title", "New conversation"),
                "last_message_preview": metadata.get("lastMessagePreview", ""),
                "created_at": metadata.get("createdAt", ""),
                "updated_at": metadata.get("updatedAt", ""),
                "message_count": metadata.get("messageCount", 0),
                "next_action": action_items[0] if action_items else "",
                "action_status": metadata.get("actionStatus", "not_started"),
                "has_report": bool(report),
                "report_summary": report.get("summary", ""),
            })
        return conversations, has_more

    async def update_conversation_title(self, conversation_id: str, title: str) -> None:
        doc = self.db.collection("conversations").document(conversation_id)
        doc.update({"metadata.title": title})

    async def get_conversation_owner(self, conversation_id: str) -> Optional[str]:
        doc = self.db.collection("conversations").document(conversation_id)
        snapshot = doc.get()
        if not snapshot.exists:
            return None
        data = snapshot.to_dict()
        metadata = data.get("metadata", {})
        return metadata.get("userId")

    async def update_action_status(self, conversation_id: str, action_status: str) -> None:
        doc = self.db.collection("conversations").document(conversation_id)
        doc.update({"metadata.actionStatus": action_status})

    async def delete_conversation(self, conversation_id: str) -> None:
        conv_ref = self.db.collection("conversations").document(conversation_id)
        # Delete messages subcollection first to avoid orphan data
        messages = list(conv_ref.collection("messages").stream())
        for msg in messages:
            msg.reference.delete()
        conv_ref.delete()

    # === Session Reports ===

    async def save_report(self, conversation_id: str, report: dict) -> None:
        doc = self.db.collection("conversations").document(conversation_id)
        doc.update({"report": report})

    async def get_report(self, conversation_id: str) -> Optional[dict]:
        doc = self.db.collection("conversations").document(conversation_id)
        snapshot = doc.get()
        if snapshot.exists:
            return snapshot.to_dict().get("report")
        return None

    # === Coaches ===

    async def create_coach(self, coach_id: str, data: dict) -> None:
        doc = self.db.collection("coaches").document(coach_id)
        doc.set(data)

    async def get_coach(self, coach_id: str) -> Optional[dict]:
        doc = self.db.collection("coaches").document(coach_id)
        snapshot = doc.get()
        if snapshot.exists:
            return snapshot.to_dict()
        return None

    async def get_coach_by_share_code(self, share_code: str) -> Optional[dict]:
        query = (self.db.collection("coaches")
                 .where("shareCode", "==", share_code)
                 .limit(1))
        results = list(query.stream())
        if results:
            data = results[0].to_dict()
            data["coach_id"] = results[0].id
            return data
        return None

    async def share_code_exists(self, code: str) -> bool:
        coach = await self.get_coach_by_share_code(code)
        return coach is not None

    async def increment_coach_usage(self, coach_id: str) -> None:
        doc = self.db.collection("coaches").document(coach_id)
        doc.update({"usageCount": fb_firestore.Increment(1)})

    async def get_user_coaches(self, user_id: str) -> list[dict]:
        """Get coaches created by user AND coaches added to user's library."""
        # 1. Coaches created by this user
        created_query = (self.db.collection("coaches")
                         .where("creatorId", "==", user_id))
        created_results = list(created_query.stream())
        coaches = []
        seen_ids = set()
        for doc in created_results:
            data = doc.to_dict()
            data["coach_id"] = doc.id
            coaches.append(data)
            seen_ids.add(doc.id)

        # 2. Coaches added via share code (stored in user's library subcollection)
        library_docs = list(
            self.db.collection("users").document(user_id)
            .collection("coach_library").stream()
        )
        for lib_doc in library_docs:
            coach_id = lib_doc.id
            if coach_id in seen_ids:
                continue
            coach_data = await self.get_coach(coach_id)
            if coach_data:
                coach_data["coach_id"] = coach_id
                coaches.append(coach_data)
                seen_ids.add(coach_id)

        return coaches

    async def add_coach_to_library(self, user_id: str, coach_id: str) -> None:
        """Save a shared coach to user's library for persistence across restarts."""
        doc = (self.db.collection("users").document(user_id)
               .collection("coach_library").document(coach_id))
        doc.set({"addedAt": __import__("datetime").datetime.utcnow().isoformat()})

    async def is_coach_in_library(self, user_id: str, coach_id: str) -> bool:
        doc = (self.db.collection("users").document(user_id)
               .collection("coach_library").document(coach_id))
        return doc.get().exists

    # === Subscription ===

    async def update_subscription(self, uid: str, plan: str) -> None:
        doc = self.db.collection("users").document(uid).collection("subscription").document("data")
        doc.set({"plan": plan}, merge=True)

    async def is_voice_trial_used(self, uid: str) -> bool:
        doc = self.db.collection("users").document(uid).collection("subscription").document("data")
        snapshot = doc.get()
        if snapshot.exists:
            return snapshot.to_dict().get("freeVoiceTrialUsed", False)
        return False

    async def mark_voice_trial_used(self, uid: str) -> None:
        doc = self.db.collection("users").document(uid).collection("subscription").document("data")
        doc.set({"freeVoiceTrialUsed": True}, merge=True)

    # === Voice Usage ===

    def _current_month_key(self) -> str:
        """Return 'YYYY-MM' for the current UTC month."""
        return datetime.utcnow().strftime("%Y-%m")

    async def get_voice_usage(self, uid: str) -> dict:
        doc = self.db.collection("voice_usage").document(uid)
        snapshot = doc.get()
        if snapshot.exists:
            data = snapshot.to_dict()
            # Auto-reset if month has changed
            if data.get("month") != self._current_month_key():
                return {"monthlyMinutes": 0, "sessions": [], "month": self._current_month_key()}
            return data
        return {"monthlyMinutes": 0, "sessions": [], "month": self._current_month_key()}

    async def update_voice_usage(self, uid: str, duration_minutes: float,
                                  session_id: str) -> None:
        doc = self.db.collection("voice_usage").document(uid)
        snapshot = doc.get()
        current_month = self._current_month_key()

        now = datetime.utcnow().isoformat()
        session_entry = {
            "sessionId": session_id,
            "duration": round(duration_minutes, 2),
            "date": now,
        }

        if snapshot.exists:
            data = snapshot.to_dict()
            # Reset if new month
            if data.get("month") != current_month:
                doc.set({
                    "monthlyMinutes": duration_minutes,
                    "sessions": [session_entry],
                    "month": current_month,
                })
            else:
                current_minutes = data.get("monthlyMinutes", 0)
                sessions = data.get("sessions", [])
                sessions.append(session_entry)
                doc.update({
                    "monthlyMinutes": current_minutes + duration_minutes,
                    "sessions": sessions,
                })
        else:
            doc.set({
                "monthlyMinutes": duration_minutes,
                "sessions": [session_entry],
                "month": current_month,
            })
