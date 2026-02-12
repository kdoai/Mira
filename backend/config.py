"""
Mira Backend Configuration
Ref: PLAN.md Section 0.1 Rule 6 (GCP Project Safety), Section 5.1
"""

import os

# === GCP Project Safety ===
# ONLY use project surveydxplatform. NEVER change this.
GCP_PROJECT_ID = "surveydxplatform"

# === Gemini Models ===
GEMINI_TEXT_MODEL = "gemini-2.5-flash-lite"
GEMINI_VOICE_MODEL = "gemini-live-2.5-flash-native-audio"

# === Locations ===
GEMINI_TEXT_LOCATION = "us-central1"
# Gemini Live uses us-central1
GEMINI_VOICE_LOCATION = "us-central1"

# === Environment Setup ===
# These MUST be set before importing genai
# Pattern from tsugiai reference project
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "1"
os.environ["GOOGLE_CLOUD_LOCATION"] = GEMINI_TEXT_LOCATION
os.environ["GOOGLE_CLOUD_PROJECT"] = GCP_PROJECT_ID

# API key fallback (set via Cloud Run env var GOOGLE_CLOUD_API_KEY)
if os.environ.get("GOOGLE_CLOUD_API_KEY"):
    os.environ.setdefault("GOOGLE_API_KEY", os.environ["GOOGLE_CLOUD_API_KEY"])

# === Rate Limits ===
# Ref: PLAN.md Section 3.2
FREE_DAILY_MESSAGE_LIMIT = 10
VOICE_MONTHLY_MINUTES_LIMIT = 60
VOICE_SESSION_MAX_MINUTES = 30
MAX_MESSAGE_LENGTH = 2000
MAX_ABOUT_ME_LENGTH = 500

# === Server ===
PORT = int(os.environ.get("PORT", 8080))
