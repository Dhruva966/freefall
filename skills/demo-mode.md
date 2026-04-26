# Skill: demo-mode

Keep the hackathon demo reliable and impressive regardless of real integration status.

## Philosophy

The demo must never fail visibly. If a real integration is unavailable (API key
missing, Ollama not running, AppleScript permission denied), the app should return
a realistic, helpful response that looks like success.

Real failures are acceptable in production. Demo failures are not acceptable on
demo day.

## Enabling Demo Mode

Set in environment:
```bash
DEMO_MODE=true
```

Or in `mac-backend/.env`:
```
DEMO_MODE=true
```

`config.py` exposes: `DEMO_MODE: bool = os.environ.get("DEMO_MODE", "false").lower() == "true"`

## Simulated Functions (current status)

| Function | Status | Simulated response |
|---|---|---|
| create_reminder | REAL (AppleScript) | Fallback if osascript unavailable |
| get_weather | REAL (OpenWeatherMap) | Simulated if key missing or DEMO_MODE |
| create_calendar_event | REAL (AppleScript) | Fallback if osascript unavailable |
| set_alarm | SIMULATED (creates Reminder, not real alarm) | Always has fallback |
| search_gmail | SIMULATED | Canned UCLA Fast Track response |

## Demo Data

Use realistic, relatable demo data. Avoid obviously fake data like "foo", "test",
"John Doe".

```python
DEMO_RESPONSES = {
    "create_reminder": "Done. Reminding you to submit your physics lab at 8:00 PM.",
    "get_weather_today": "Today: 72°F (feels 70°F), Sunny. Great afternoon.",
    "get_weather_tomorrow": "Tomorrow: 65°F (feels 62°F), Partly cloudy.",
    "create_calendar_event": "Added robotics practice 4:00–6:00 PM tomorrow.",
    "set_alarm": "Set an alarm reminder for 7:00 AM. It'll ping all your Apple devices.",
    "search_gmail": "Found it. The UCLA Fast Track email mentions a Zoom info session on May 3rd.",
    "unknown": "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\"",
}
```

## Code Pattern

Separate simulated from real clearly. Use `# SIMULATED` comment on canned paths:

```python
def search_gmail(query: str) -> str:
    if DEMO_MODE or not _gmail_configured():
        return DEMO_RESPONSES["search_gmail"]  # SIMULATED
    return _real_gmail_search(query)
```

Never silently fall through from real to simulated — log it:
```python
print(f"[demo] returning simulated response for {intent}")
```

## iOS MockMessageRouter

`MockMessageRouter` in `MessageRouting.swift` is always the iOS demo path.
It must:
- Return a response for every test phrase used in demos.
- Never make network calls.
- Never fail.

Maintain a list of demo phrases that always work:
- "Remind me to submit my physics lab tonight at 8" → create_reminder
- "What's the weather tomorrow morning?" → get_weather
- "Add robotics practice tomorrow from 4 to 6" → create_calendar_event
- "Find the UCLA Fast Track email" → search_gmail
- "Set an alarm for 7 AM" → set_alarm

Test all five before every demo.

## Graceful Failure UX

When something fails, the user-facing message should:
- Sound natural, not like an error.
- Suggest what to try instead.
- Never show stack traces, exception types, or technical details.

Good: `"Can't reach weather right now. Try again in a moment."`
Bad: `"requests.exceptions.ConnectionError: HTTPSConnectionPool..."`

## Ollama Unavailable

If Ollama is down and `DEMO_MODE=true`, bypass the LLM entirely:
- Simple keyword matching in `gemma_router.py` as fast fallback.
- Match: "remind" → create_reminder, "weather" → get_weather, etc.
- Return demo response directly without Ollama call.

## Pre-Demo Checklist

Before any demo or presentation:

- [ ] `DEMO_MODE=true` set in environment.
- [ ] All five demo phrases tested in iOS MockMessageRouter.
- [ ] Mac backend: curl all five intents and verify responses.
- [ ] Ollama running (or DEMO_MODE bypasses it).
- [ ] Messages.app open and signed in (for live iMessage demo).
- [ ] Mac sleep disabled.
- [ ] UI looks clean: no debug print overlays, no error banners.
