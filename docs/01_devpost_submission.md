# Mira — AI Coaching, Simplified

> Shipyard 2026 Hackathon | Better Creating Brief

## Inspiration

Before I became a strategy consultant, I was lost. I had the ambition but lacked clarity — about what I wanted, about how to get there, about how to think through complex decisions without spiraling. A coaching engagement changed that for me. In just a few sessions, I learned frameworks for structured thinking, self-reflection, and intentional goal-setting that transformed my career trajectory.

Years later, as I built my own consulting practice and led teams, I found myself applying those same coaching principles — asking powerful questions, helping people reframe problems, guiding without prescribing — in every team meeting and 1-on-1.

When Simon's brief landed — asking to make AI coaching "as calm, accessible, and intentional as a meditation app" — it resonated immediately. His core premise is right: coaching is expensive ($200–500/hour), finding the right fit is daunting, and most people who would benefit from it never get the chance to try. That matched what I'd seen in my own career.

I agreed with that direction and knew what I wanted to build: not another chatbot, not another productivity tool, but a genuine coaching experience — minimalist, warm, and designed to create real forward momentum.

## What it does

**Mira** is a minimalist AI coaching app that puts high-quality coaching in everyone's pocket.

**5 Expert Coaches:** Each coach has a distinct personality, methodology, and focus area — General (Mira), Career (Atlas), Creativity (Lyra), Wellness (Sol), and Relationships (Ember). They're built on real coaching frameworks: the GROW Model, Motivational Interviewing, and ICF Core Competencies.

**Real-Time Voice Coaching:** Talk to your coach like you would a real person. Bidirectional audio streaming through Gemini Live API creates natural, flowing conversations — no typing required.

**Personal Context:** A simple "About Me" field lets users share who they are, what they care about, and what they're working toward. This context is woven into every coaching session, making responses deeply personal.

**Create & Share Coaches:** Build custom AI coaches with a specific focus and coaching style, then share them with friends and colleagues via simple 8-character codes.

**Session Reports:** After each conversation, Mira generates a Notion-style report with a summary, key insights, action items, and mood observation — turning every session into actionable progress.

**Journal & Follow-ups:** Active action items live on the Journal tab, with gentle reminders on the Home screen. Coaching isn't just about conversation — it's about follow-through.

## How we built it

**Frontend:** Flutter (Dart) for Android, using Riverpod for state management and GoRouter for navigation. The design system uses a warm, earthy palette inspired by Notion and Apple's design language — Forest Green (#2D5A3D), Warm Earth (#A68B6B), Warm White (#F8F6F3).

**Backend:** Python FastAPI deployed on Google Cloud Run, handling all AI interactions server-side. Text chat uses SSE (Server-Sent Events) for real-time streaming. Voice coaching uses a WebSocket proxy that bridges the Flutter client to Gemini Live's bidirectional audio API.

**AI:** Gemini 2.5 Flash Lite for text conversations (fast, cost-effective), Gemini Live 2.5 Flash Native Audio for real-time voice coaching. Each coach has a carefully crafted system prompt based on real coaching methodologies.

**Auth & Data:** Firebase Authentication (Google Sign-In) with Cloud Firestore for all user data. Security rules ensure users can only access their own conversations.

**Billing:** RevenueCat manages Google Play subscriptions with server-side verification — the backend never trusts client claims about subscription status.

## Challenges we ran into

**Voice pipeline complexity:** Bridging Flutter's audio capture to Gemini Live's WebSocket API through a Cloud Run proxy required careful handling of binary audio frames, session lifecycle, and connection timeouts. Cloud Run's default 15-minute WebSocket timeout needed explicit configuration (--timeout=3600s).

**Server-side enforcement:** Early versions had the classic "client-side only" security gap. Free users could bypass the paywall by calling the API directly. I rebuilt the entire enforcement layer server-side — every premium feature returns HTTP 403 on the backend, not just a UI block.

**Coaching quality:** Generic AI responses feel hollow. Getting each coach to feel distinct, warm, and genuinely helpful required extensive prompt engineering. The key insight: "never prescribe" is too rigid — good coaching offers options and lets the user choose.

## Accomplishments that we're proud of

The brief asked: *"What if AI coaching were as calm, accessible, and intentional as a meditation app?"* Here's how Mira answers that:

- **"Calm as a meditation app"** — Mira opens to a warm, minimal Home screen with a single coach card front and center. Forest Green and Warm Earth palette, not the typical blue-tech look. No dashboards, no metrics, no feature overload. Users open the app when they need clarity, because it doesn't feel like work.

- **"Friction for people who don't use advanced workspace tools"** — 3 taps to your first coaching session: sign in with Google, tap a coach, start talking. No tutorials, no onboarding forms, no learning curve. Bottom navigation with just 3 tabs. The brief identified people who "prefer mobile-first, lightweight experiences" — Mira is built exactly for them.

- **"Different modes of thinking when they need them"** — 5 coaches with distinct methodologies, not just different labels. Career decisions get strategic frameworks (Atlas). Creative blocks get divergent thinking exercises (Lyra). Wellness gets mindful reflection (Sol). Users get the right kind of coaching for their current situation.

- **"Personal context to gently inform conversations"** — One free-text About Me field — no structured questionnaire, no mandatory fields. That context is woven into every session automatically. Sessions feel personal from the first message, without re-explaining who you are each time.

- **"Conversations that result in clear takeaways"** — Every session generates a Notion-style report: summary, key insights, concrete action items, mood observation. Action items persist on the Home screen with gentle follow-up reminders. Users leave with next steps, not just a good feeling.

- **"Not to replace real human coaches — but to support and complement them"** — Real-time voice coaching through Gemini Live makes conversations feel like talking to a person, not typing at a machine. Speaking out loud activates different thinking than typing — users process complex decisions more naturally, the way they would with a real coach.

## What we learned

- **Coaching is a framework, not just conversation.** The GROW Model and Motivational Interviewing techniques translate surprisingly well to AI when the prompts are structured correctly.
- **Simplicity is harder than complexity.** Cutting the About Me from a structured form to a single free-text field was the best UX decision I made — and the hardest to commit to.
- **Voice changes everything.** Text coaching is useful. Voice coaching is transformative. The emotional bandwidth of spoken conversation creates a qualitatively different coaching experience.
- **Cut features, never quality.** I dropped dark mode, deep links, and several planned features to maintain production-grade polish on every screen that shipped.

## What's next for Mira

- **iOS release** — Flutter makes cross-platform deployment straightforward
- **Conversation memory** — AI that remembers insights across sessions, building a longitudinal coaching relationship
- **Coach marketplace** — discover and subscribe to coaches created by the community
- **Team coaching** — shared coaching spaces for teams, with group insights and collaborative action items
- **Integration with productivity tools** — action items that sync to Notion, Todoist, or Apple Reminders

## Built with

- Flutter (Dart)
- Python FastAPI
- Google Cloud Run
- Google Gemini 2.5 Flash Lite
- Google Gemini Live 2.5 Flash Native Audio
- Firebase Authentication
- Cloud Firestore
- RevenueCat
- Google Play Billing

## Demo Video

[Video link placeholder — to be added]
