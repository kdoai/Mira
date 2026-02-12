"""
Mira Backend — FastAPI Application
Ref: PLAN.md Section 5.5 (Production Server Config), Section 0.4 (Logging)

GCP Project: surveydxplatform (ONLY — see PLAN.md Section 0.1 Rule 6)
"""

import logging
import json

# Configure logging FIRST — minimal, no message content
# Ref: PLAN.md Section 0.4
logging.basicConfig(
    level=logging.INFO,
    format='{"level":"%(levelname)s","logger":"%(name)s","message":"%(message)s"}',
)
logger = logging.getLogger("mira")

# Import config (sets environment variables before genai import)
import config

import firebase_admin
from firebase_admin import credentials

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Initialize Firebase Admin SDK
# On Cloud Run, uses default service account credentials
if not firebase_admin._apps:
    firebase_admin.initialize_app()

# Create FastAPI app
app = FastAPI(
    title="Mira API",
    description="AI Coaching Backend",
    version="1.0.0",
)

# CORS — acceptable for mobile app backend
# Ref: PLAN.md Section 5.5
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check — cold start prevention
# Ref: PLAN.md Section 5.5
@app.get("/health")
async def health_check():
    return {"status": "ok", "project": config.GCP_PROJECT_ID}


# Static pages — required by Google Play
from fastapi.responses import HTMLResponse

_PAGE_STYLE = """<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,system-ui,'Segoe UI',sans-serif;max-width:720px;margin:0 auto;padding:32px 24px;color:#1C1C1E;line-height:1.7;background:#F8F6F3}
h1{color:#2D5A3D;font-size:28px;margin-bottom:8px}
h2{color:#2D5A3D;font-size:20px;margin-top:32px;margin-bottom:12px}
p{margin-bottom:12px}
ul{margin:0 0 16px 24px}
li{margin-bottom:6px}
a{color:#2D5A3D;text-decoration:none;font-weight:600}
a:hover{text-decoration:underline}
.subtitle{color:#A68B6B;font-size:14px;margin-bottom:24px}
.card{background:#fff;border-radius:12px;padding:24px;margin:20px 0;box-shadow:0 1px 3px rgba(0,0,0,0.08)}
.btn{display:inline-block;background:#2D5A3D;color:#fff;padding:14px 28px;border-radius:10px;font-size:16px;font-weight:600;text-decoration:none;margin:8px 8px 8px 0}
.btn:hover{background:#1e3d29;text-decoration:none}
.btn-outline{background:transparent;color:#2D5A3D;border:2px solid #2D5A3D}
.btn-outline:hover{background:#2D5A3D;color:#fff}
.contact-box{background:#2D5A3D;color:#fff;border-radius:12px;padding:24px;margin-top:32px}
.contact-box a{color:#D4A574}
footer{margin-top:40px;padding-top:20px;border-top:1px solid #e0ddd8;color:#A68B6B;font-size:13px}
</style>"""

_PAGE_HEAD = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">"""


@app.get("/privacy", response_class=HTMLResponse)
async def privacy_policy():
    return f"""{_PAGE_HEAD}
<title>Mira - Privacy Policy</title>
{_PAGE_STYLE}
</head>
<body>
<h1>Privacy Policy</h1>
<p class="subtitle">Last updated: February 12, 2026</p>

<div class="card">
<h2>1. Overview</h2>
<p>Mira ("we", "our", "the app") is an AI coaching application. We respect your privacy and are committed to protecting your personal data.</p>
</div>

<div class="card">
<h2>2. Data We Collect</h2>
<ul>
<li><strong>Account Information:</strong> Google account name and email (via Google Sign-In) for authentication.</li>
<li><strong>Chat Messages:</strong> Text messages you send during coaching sessions, stored to provide session history and reports.</li>
<li><strong>Voice Audio:</strong> Microphone audio is streamed in real-time to Google's Gemini API for voice coaching. Audio is processed in real-time and is <strong>not stored</strong> on our servers.</li>
<li><strong>About Me:</strong> Optional personal context you provide to personalize coaching.</li>
<li><strong>Subscription Data:</strong> Purchase status via RevenueCat to manage Pro features.</li>
</ul>
</div>

<div class="card">
<h2>3. Microphone Usage</h2>
<p>Mira uses the microphone (<code>RECORD_AUDIO</code>) exclusively for the voice coaching feature. Audio is streamed directly to Google's Gemini AI for real-time conversation and is not recorded or stored by Mira.</p>
</div>

<div class="card">
<h2>4. How We Use Your Data</h2>
<ul>
<li>To provide AI coaching sessions (text and voice)</li>
<li>To generate session reports and action items</li>
<li>To personalize coaching with your About Me context</li>
<li>To manage your subscription status</li>
</ul>
</div>

<div class="card">
<h2>5. Data Storage</h2>
<p>Data is stored securely in Google Cloud Firestore. Each user's data is isolated and accessible only to that user.</p>
</div>

<div class="card">
<h2>6. Third-Party Services</h2>
<ul>
<li><strong>Google Cloud / Gemini AI:</strong> AI processing for coaching</li>
<li><strong>Firebase Authentication:</strong> Secure sign-in</li>
<li><strong>RevenueCat:</strong> Subscription management</li>
</ul>
</div>

<div class="card">
<h2>7. Data Deletion</h2>
<p>You can delete your coaching sessions from the History tab. To delete your account and all associated data, contact us at the email below.</p>
</div>

<div class="contact-box">
<h2 style="color:#fff;margin-top:0">8. Contact</h2>
<p style="margin:0">For privacy questions, contact: <a href="mailto:omotenashisamurai.japan@gmail.com">omotenashisamurai.japan@gmail.com</a></p>
</div>

<footer>
<p>&copy; 2026 Mira. All rights reserved. | <a href="/support">Help &amp; Support</a> | <a href="/manage-subscription">Manage Subscription</a></p>
</footer>
</body>
</html>"""


@app.get("/support", response_class=HTMLResponse)
async def help_support():
    return f"""{_PAGE_HEAD}
<title>Mira - Help &amp; Support</title>
{_PAGE_STYLE}
</head>
<body>
<h1>Help &amp; Support</h1>
<p class="subtitle">We're here to help you get the most out of Mira.</p>

<div class="card">
<h2>Getting Started</h2>
<ul>
<li><strong>Sign in</strong> with your Google account to start coaching.</li>
<li><strong>Choose a coach</strong> from the Home screen — Mira (General) is free for everyone.</li>
<li><strong>Start chatting</strong> — type your message or use voice coaching (Pro).</li>
<li><strong>Review sessions</strong> in the History tab to track your progress.</li>
</ul>
</div>

<div class="card">
<h2>Frequently Asked Questions</h2>
<p><strong>Q: How do I upgrade to Pro?</strong><br>
Tap the upgrade button on the Home screen or any Pro coach card. Pro unlocks all 5 coaches, unlimited messages, 60 min/month voice coaching, and custom coach creation.</p>

<p><strong>Q: How do I cancel my subscription?</strong><br>
Open the Google Play Store app &rarr; tap your profile icon &rarr; Payments &amp; subscriptions &rarr; Subscriptions &rarr; Mira &rarr; Cancel. You'll keep Pro access until the end of your billing period.</p>

<p><strong>Q: Is my data private?</strong><br>
Yes. Your conversations are stored securely and only accessible to you. Voice audio is processed in real-time and never stored. See our <a href="/privacy">Privacy Policy</a> for details.</p>

<p><strong>Q: How does voice coaching work?</strong><br>
Voice coaching uses Google's Gemini AI for real-time conversation. Tap the microphone icon in a chat to start a voice session. Free users get one 5-minute trial; Pro unlocks 60 minutes per month.</p>

<p><strong>Q: Can I create my own coach?</strong><br>
Yes! Pro users can create custom coaches with a unique name, focus area, and coaching style. You can also share your coaches with others using a share code.</p>
</div>

<div class="contact-box">
<h2 style="color:#fff;margin-top:0">Contact Us</h2>
<p>Need more help? Reach out to us:</p>
<p style="margin:0"><a href="mailto:omotenashisamurai.japan@gmail.com">omotenashisamurai.japan@gmail.com</a></p>
</div>

<footer>
<p>&copy; 2026 Mira. All rights reserved. | <a href="/privacy">Privacy Policy</a> | <a href="/manage-subscription">Manage Subscription</a></p>
</footer>
</body>
</html>"""


@app.get("/manage-subscription", response_class=HTMLResponse)
async def manage_subscription():
    return f"""{_PAGE_HEAD}
<title>Mira - Manage Subscription</title>
{_PAGE_STYLE}
</head>
<body>
<h1>Manage Subscription</h1>
<p class="subtitle">View and manage your Mira Pro subscription.</p>

<div class="card">
<h2>Mira Pro</h2>
<p>Your Pro subscription is managed through Google Play. Use the link below to view, update, or cancel your subscription.</p>
<a href="https://play.google.com/store/account/subscriptions?sku=mira_pro_monthly&package=com.miracoach.mira" class="btn">Manage on Google Play</a>
</div>

<div class="card">
<h2>What's Included in Pro</h2>
<ul>
<li>All 5 expert coaches (Atlas, Lyra, Sol, Ember) + custom coaches</li>
<li>Unlimited text messages (free: 10/day)</li>
<li>Voice coaching — 60 min/month, up to 30-min sessions (free: 1 trial)</li>
<li>Create &amp; share custom coaches</li>
</ul>
</div>

<div class="card">
<h2>Pricing</h2>
<p><strong>Monthly:</strong> $9.99/month</p>
<p><strong>Yearly:</strong> $79.99/year (save 33%)</p>
<p style="color:#A68B6B;font-size:14px">Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. You can cancel anytime from Google Play.</p>
</div>

<div class="card">
<h2>Cancel Subscription</h2>
<p>To cancel your subscription:</p>
<ol style="margin:0 0 0 24px">
<li>Open the <strong>Google Play Store</strong> app</li>
<li>Tap your <strong>profile icon</strong> (top right)</li>
<li>Tap <strong>Payments &amp; subscriptions</strong></li>
<li>Tap <strong>Subscriptions</strong></li>
<li>Select <strong>Mira</strong> and tap <strong>Cancel</strong></li>
</ol>
<p style="margin-top:12px">You'll keep Pro access until the end of your current billing period.</p>
</div>

<div class="contact-box">
<h2 style="color:#fff;margin-top:0">Need Help?</h2>
<p>Having trouble with your subscription? Contact us:</p>
<p style="margin:0"><a href="mailto:omotenashisamurai.japan@gmail.com">omotenashisamurai.japan@gmail.com</a></p>
</div>

<footer>
<p>&copy; 2026 Mira. All rights reserved. | <a href="/privacy">Privacy Policy</a> | <a href="/support">Help &amp; Support</a></p>
</footer>
</body>
</html>"""


# SSE test endpoint (no auth) — for debugging
@app.get("/test/sse")
async def test_sse():
    import asyncio
    from sse_starlette.sse import EventSourceResponse
    async def generate():
        for i in range(5):
            yield {"event": "message", "data": json.dumps({"text": f"Test chunk {i+1}. "})}
            await asyncio.sleep(0.3)
        yield {"event": "done", "data": ""}
    return EventSourceResponse(generate(), media_type="text/event-stream")

# Import and include routers
from routers import chat, voice, coaches, profile, sessions

app.include_router(chat.router, prefix="/chat", tags=["Chat"])
app.include_router(voice.router, tags=["Voice"])
app.include_router(coaches.router, prefix="/coaches", tags=["Coaches"])
app.include_router(profile.router, prefix="/profile", tags=["Profile"])
app.include_router(sessions.router, prefix="/conversations", tags=["Sessions"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=config.PORT)
