# Mira — AI Coaching, Simplified

**Shipyard 2026 Hackathon Entry | Better Creating Brief**

> "What if AI coaching were as calm, accessible, and intentional as a meditation app — but designed to help you make real progress?"

---

## What is Mira?

Mira is a minimalist AI coaching app that makes high-quality coaching accessible to everyone. Browse expert coaches, create your own, add personal context, and start a conversation — text or voice — in seconds.

**Built for Simon's audience**: productivity-focused professionals who love well-designed tech that solves problems practically.

## Brief Requirements (Influencer)

The following are the core requirements from Simon's Better Creating brief:

- Calm, minimal, mobile-first AI coaching experience
- Multiple coaches for different life areas
- Easy personal context input ("About Me")
- Conversation memory and session continuity
- Session output with clear takeaways
- Free-to-paid model with room for premium/advanced coaching instructions
- Human-centered framing (supporting real coaching, not replacing it)
- No direct reuse of AgentOS prompts/IP

## My Response and Why I Agreed

I strongly agreed with the brief's core idea: coaching should feel accessible and human, not technical.
Based on that, I chose to prioritize low-friction onboarding, warm UI, and practical session outcomes over feature bloat.

## My Product Decisions (Implementation)

| My Decision | Why I Chose It |
|---|---|
| 5 expert coaches (General, Career, Creativity, Wellness, Relationships) | Matches "different modes of thinking" from the brief |
| Custom coach creation + share codes | Supports personalization and audience/community growth |
| "About Me" as one free-text field | Lowest-friction context capture for mobile |
| Session reports + action items | Makes conversations produce concrete outcomes |
| Voice coaching (Gemini Live) | Makes coaching feel immediate and human |
| Free + Pro subscription model | Aligns with brief's free trial + paid portal direction |
| Prompt system built from scratch | Respects the "do not reuse AgentOS prompts" requirement |

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) — Android |
| Backend | Python FastAPI on Google Cloud Run |
| AI (Text) | Gemini 2.5 Flash Lite (direct genai.Client API) |
| AI (Voice) | Gemini Live 2.5 Flash Native Audio (WebSocket proxy) |
| Auth | Firebase Authentication (Google Sign-In) |
| Database | Google Cloud Firestore |
| Billing | RevenueCat (Google Play subscriptions) |
| Project | GCP `surveydxplatform` |

## Key Features

- **5 Named Coaches** — Mira (General), Atlas (Career), Lyra (Creativity), Sol (Wellness), Ember (Relationships)
- **Real-time Voice Coaching** — bidirectional audio streaming through Gemini Live API
- **Custom Coach Creation & Sharing** — create coaches with custom focus and style, share via codes
- **Personal Context ("About Me")** — single free-text field injected into every coaching session
- **Session Reports** — AI-generated summaries formatted like Notion pages
- **Action Items & Follow-ups** — track next steps, mark complete, gentle reminders on Home screen
- **Streaming Text Responses** — SSE streaming for real-time chat experience
- **Production-Grade Quality** — loading/empty/error states, smooth animations, proper input handling

## Revenue Model

| Tier | Price | Features |
|---|---|---|
| Free | $0 | General Coach (Mira), 10 messages/day, 1 free 5-min voice session, session reports |
| Pro Monthly | $9.99/mo | All coaches, unlimited messages, 60 min/mo voice (30 min/session), custom coaches |
| Pro Yearly | $79.99/yr | Same as monthly (save 33%) |

~80% gross margin on Pro tier. Server-side enforcement via RevenueCat API verification.

## Architecture

```
Flutter App
  ├── Firebase Auth (Google Sign-In)
  ├── REST API → Cloud Run (FastAPI)
  │     ├── POST /chat/send (SSE streaming)
  │     ├── WS /ws/voice/{id} (bidirectional audio proxy)
  │     ├── GET /coaches/mine, POST /coaches/create
  │     ├── GET /conversations, POST /conversations/{id}/report
  │     └── POST /profile/subscription/sync (RevenueCat verification)
  └── Firestore (conversations, messages, coaches, profiles)
```

## Security

- All premium features enforced server-side (OWASP CWE-602 compliant)
- Firebase ID token required on all API endpoints
- RevenueCat subscription verified server-to-server (never trust client claims)
- No secrets in Flutter client — all through Cloud Run
- Firestore security rules: users can only read their own data

## Demo Flow

1. Open app → 2-page onboarding → Google Sign-In
2. Home screen → tap Mira (General Coach) → start text chat
3. Chat with streaming responses → generate session report
4. Try voice coaching (microphone icon)
5. Explore Pro coaches (Atlas, Lyra, Sol, Ember)
6. Create a custom coach → share via code
7. Profile → About Me → personalize coaching context

## Running Locally

```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn main:app --reload

# Flutter
cd app
flutter pub get
flutter run
```

---

Built with care for Shipyard 2026.
