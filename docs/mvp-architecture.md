# MVP Architecture — Free Fall

## Message Flow

```
User sends iMessage to Free Fall contact
        │
        ▼
~/Library/Messages/chat.db
  (polled every 1.5s)
        │
        ▼
message_monitor.py
  - copies DB to temp file (avoids WAL lock)
  - queries new rows since last_rowid
  - filters: is_from_me=0, text NOT NULL
        │
        ▼
main.py  dispatcher
        │
        ▼
gemma_router.py
  - builds system prompt with current datetime
  - calls Ollama (gemma3:1b) via HTTP POST
  - extracts JSON from response
  - retries once on parse failure
  - returns: { intent, params, response }
        │
        ├──► create_reminder ──► applescript_executor.create_reminder()
        │                               │
        ├──► get_weather ──────► weather_service.get_weather()
        │                               │
        ├──► create_calendar_event ──► applescript_executor.create_calendar_event()
        │                               │
        ├──► set_alarm ────────► applescript_executor.set_alarm()
        │                               │
        ├──► search_gmail ─────► GMAIL_CANNED (simulated v1)
        │                               │
        └──► clarify / unknown ─► model_response string
                                        │
                                        ▼
                            applescript_executor.send_imessage()
                              - osascript → Messages.app
                                        │
                                        ▼
                            User receives iMessage reply
```

## HTTP Test Path (server.py)

For testing without a live iMessage setup:

```
POST /message  { "text": "...", "sender": "demo" }
        │
        ▼
server.py  (FastAPI)
        │
        ▼
same gemma_router → executor chain
        │
        ▼
{ "reply": "..." }  (JSON response — no AppleScript send)
```

## iOS Demo Path (SwiftUI)

```
User types in ChatView
        │
        ▼
ChatViewModel.send()
        │
        ▼
MockMessageRouter.route()  (keyword matching, no network)
        │
        ▼
ActionExecutor.execute()  (simulated actions)
        │
        ▼
Reply bubble in ChatView
```

The iOS app is a demo/companion UI. The real assistant runs on the Mac.

---

## Component Responsibilities

| Component | Responsibility | Does NOT do |
|---|---|---|
| `message_monitor.py` | Poll chat.db, detect new messages | Routing, executing, sending |
| `gemma_router.py` | NLP → intent JSON via LLM | Executing actions, sending replies |
| `main.py` | Dispatch intent to correct executor | LLM calls, DB polling |
| `applescript_executor.py` | Execute macOS actions via AppleScript | Routing, LLM, weather |
| `weather_service.py` | Fetch OpenWeatherMap forecast | Anything else |
| `server.py` | HTTP API wrapper for testing | Polling, direct AppleScript send |
| `config.py` | Constants and env var loading | Business logic |
| `ChatView.swift` | UI only | Intent routing, action execution |
| `MockMessageRouter.swift` | Demo routing (keyword match) | Network calls, real actions |

---

## Recommended MVP Stack (current)

| Layer | Technology |
|---|---|
| Transport | iMessage via chat.db polling + AppleScript |
| LLM | Gemma3:1b via Ollama (local, on-device) |
| Actions | AppleScript (Reminders, Calendar, Messages) |
| Weather | OpenWeatherMap REST API (HTTPS) |
| Gmail | Simulated (canned response) |
| HTTP interface | FastAPI + uvicorn (test/debug only) |
| iOS UI | SwiftUI + MockMessageRouter |
| Language | Python 3.12+ (backend), Swift 5.9+ (iOS) |

---

## Future Architecture (v2+)

```
User texts Free Fall
        │
        ▼
iMessage / SMS transport
  (option A: same Mac chat.db polling)
  (option B: Shortcuts automation on iPhone)
        │
        ▼
Intent Router
  (option A: Gemma on Mac via Ollama)
  (option B: on-device CoreML model in iOS app)
        │
        ▼
Function Registry (expanded)
  - create_reminder         ✅ done
  - get_weather             ✅ done
  - create_calendar_event   ✅ done
  - set_alarm               🟡 partial
  - search_gmail            🟡 simulated → real OAuth
  - play_music              ❌ planned
  - send_message            ❌ planned
  - web_search              ❌ planned
  - set_timer               ❌ planned
        │
        ▼
User location awareness
  - city preference per sender
  - timezone awareness
        │
        ▼
Persistent conversation context
  - per-sender history window
  - preferences storage
```

---

## Key Constraints

1. **Mac is required.** No iMessage API outside macOS. No workaround exists.
2. **Ollama must be running** for the LLM path. DEMO_MODE bypasses it.
3. **Full Disk Access** required for Terminal to read chat.db.
4. **Automation permission** required for Terminal to control Messages.app.
5. **Mac sleep = bot stops.** Set to Never Sleep in System Settings.
6. **AppleScript is slow** (~1-2s per send). Fine for assistant use.
7. **Clock.app has no AppleScript dictionary.** Alarms use Reminder fallback.
8. **Group chats not supported in MVP.** handle_id logic differs.
