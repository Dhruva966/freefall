# Free Fall — Local-First iMessage AI Assistant

## Project Overview
Free Fall is a privacy-first AI assistant that lives inside iMessage. 
No app to download. User just texts a phone number and the assistant responds.

**The pitch:** Like Poke (poke.com, $300M valuation, TechCrunch-covered) but 
fully on-device. Poke routes everything through cloud servers. Free Fall's LLM 
runs locally, data never leaves the Mac/phone, actions execute via Apple Shortcuts.

---

## Architecture

```
User sends iMessage
    → chat.db (SQLite) polled every 1.5s by bot.py
    → New message detected
    → Text passed to function matcher (functions.py)
    → If no function match → passed to local LLM (llm.py)
    → Response generated
    → AppleScript sends reply back via Messages.app
    → User receives iMessage response
```

### Stack
| Layer | Implementation |
|---|---|
| Transport | AppleScript + `~/Library/Messages/chat.db` polling |
| Interface | iMessage (native Messages.app on Mac) |
| NLP → Actions | Function calling layer (`functions.py`) |
| Actions | Apple Shortcuts (triggered via `shortcuts run`) |
| LLM Backend | Local Mistral model (on-device, no internet required) |
| Language | Python 3 |

---

## File Structure

```
freefall/
├── CLAUDE.md              ← you are here
├── bot.py                 ← main polling loop, entry point
├── send.py                ← AppleScript sender
├── functions.py           ← NLP → Shortcuts mapping layer
├── llm.py                 ← local Mistral integration
├── db.py                  ← chat.db query helpers
└── shortcuts/             ← Apple Shortcuts definitions
```

---

## Key Files — What Each Does

### bot.py
Main entry point. Polls `chat.db` every 1.5 seconds for new incoming messages.
On new message: passes text to `functions.py` first, then `llm.py` as fallback.
Calls `send.py` to deliver the response.

### send.py
Wraps AppleScript via Python `subprocess`. Takes a phone number + message string,
fires `osascript` to send through Messages.app. Phone numbers must be E.164 format
(+1XXXXXXXXXX).

### functions.py
The NLP → action mapping layer. Takes raw user text, matches it to a predefined
function (set reminder, add calendar event, etc.), and triggers the corresponding
Apple Shortcut. Returns None if no function matches, so bot.py falls through to LLM.

### db.py
SQLite helpers for reading `chat.db`. Handles the ROWID cursor so we don't
reprocess old messages. Note: iMessage stores timestamps as seconds since
2001-01-01 (not Unix epoch) — always convert accordingly.

### llm.py
Interface to the local Mistral model. Takes message text + conversation context,
returns a response string. Runs fully on-device via [ollama / llama.cpp — TBD].

---

## Current MVP Goal

**Phase 1 (Hackathon MVP):**
- [ ] bot.py polls chat.db and detects new messages
- [ ] send.py sends a reply via AppleScript
- [ ] Trigger: user says "apple pie" → bot replies "hello"
- [ ] End-to-end pipeline confirmed working

**Phase 2:**
- [ ] Connect local LLM (Mistral via ollama)
- [ ] Basic conversational responses

**Phase 3:**
- [ ] Function calling layer (NLP → Shortcuts)
- [ ] Set reminders, calendar events, alarms

---

## Mac Setup Requirements

These must be configured on the Mac running the bot or nothing will work:

1. **Full Disk Access** — System Settings → Privacy & Security → Full Disk Access → add `Terminal` (and Python binary if needed)
2. **Automation permission** — System Settings → Privacy & Security → Automation → allow Terminal to control Messages
3. **Messages.app** must be open and actively signed into iMessage
4. **System sleep disabled** — System Settings → Battery → set sleep to Never. If the Mac sleeps, the bot goes silent with no error.
5. **Messages.app signed in** — must be signed into the same Apple ID receiving messages

---

## chat.db Key Schema

The iMessage SQLite database lives at `~/Library/Messages/chat.db`.

```sql
-- Core query for new incoming messages
SELECT 
    m.ROWID,
    m.text,
    m.is_from_me,      -- 0 = incoming, 1 = sent by us
    m.date,            -- seconds since 2001-01-01 00:00:00 UTC (NOT Unix epoch)
    h.id AS sender     -- phone number or email, e.g. +11234567890
FROM message m
JOIN handle h ON m.handle_id = h.ROWID
WHERE m.ROWID > :last_rowid 
  AND m.is_from_me = 0
  AND m.text IS NOT NULL
ORDER BY m.ROWID ASC
```

**Critical:** `m.date` uses Apple's epoch (Jan 1 2001), not Unix epoch.
To convert: `unix_time = apple_time + 978307200`

---

## Apple Shortcuts Integration

Functions map to Shortcuts by name. Trigger via:
```python
subprocess.run(["shortcuts", "run", "ShortcutName"])
# With input:
subprocess.run(["shortcuts", "run", "SetReminder", "--input-string", "Take meds at 9pm"])
```

Pre-build these Shortcuts in the Shortcuts app on the same Mac:
- `SetReminder` — creates a reminder from text input
- `AddCalendarEvent` — adds event to Calendar
- `SetAlarm` — sets an alarm in Clock

---

## AppleScript Send Template

```applescript
tell application "Messages"
    set targetBuddy to "{phone_number}"
    set targetService to 1st service whose service type = iMessage
    set theBuddy to buddy targetBuddy of targetService
    send "{message}" to theBuddy
end tell
```

Called via Python: `subprocess.run(["osascript", "-e", script])`

**Known issues:**
- Escape double quotes in message text before injecting into script
- If buddy not found, Messages.app may throw — wrap in try/except
- First message to a new number may be slow (~2-3s)

---

## Privacy Model

| What happens | Where it stays |
|---|---|
| Message processing | On-device (Mac) |
| LLM inference | On-device (Mistral local) |
| Shortcut execution | On-device (Apple Shortcuts) |
| iMessage transport | Apple's E2E encrypted network |
| User data | Never leaves the Mac |

Internet is only needed for: weather APIs, web search (if added later).
Core assistant functionality works fully offline.

---

## Known Constraints & Gotchas

- **No official Apple API** — everything relies on chat.db reading + AppleScript. Apple could change this.
- **Mac is required** — there is no workaround. iMessage requires macOS.
- **AppleScript is slow** — ~1-2s per send. Acceptable for assistant use, not for bulk.
- **Lightweight LLM tradeoffs** — local Mistral is less capable than GPT-4/Claude. Scope functions accordingly.
- **chat.db locking** — open with `check_same_thread=False` and handle `sqlite3.OperationalError` for locked DB.
- **Group chats** — `handle_id` logic is different for group chats. Scope MVP to 1:1 messages only.

---

## Competitive Context

**Poke** (poke.com) — direct competitor, launched March 2026, $300M valuation.
Uses Linq API for iMessage transport + cloud LLM backend. Our differentiator:
everything runs locally, zero cloud dependency, privacy-first.

**BlueBubbles** — open source Mac iMessage bridge. Similar transport approach,
different use case (cross-device sync vs. AI assistant).

**Linq / Blooio** — commercial iMessage APIs. Cloud-based. We avoid these to
preserve the privacy-first architecture.