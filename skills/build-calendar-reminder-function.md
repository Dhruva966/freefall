# Skill: build-calendar-reminder-function

Build or update calendar event and reminder functions.

## Relevant Files

- `mac-backend/applescript_executor.py` — `create_reminder()`, `create_calendar_event()`, `set_alarm()`
- `mac-backend/main.py` — dispatcher branches for these intents
- `mac-backend/gemma_router.py` — prompt schema and examples
- `FreeFall/FreeFall/Model/IntentResult.swift` — Swift model
- `FreeFall/FreeFall/Model/MessageRouting.swift` — MockMessageRouter demo paths

## create_reminder

**Required params:** `title` (str), `datetime` (ISO 8601)

AppleScript target: Reminders.app → list "Reminders"

Date format for AppleScript: `"%A, %B %d, %Y at %I:%M %p"`
(e.g., "Friday, April 25, 2026 at 08:00 PM")

Reply format: `"Done. Reminding you to {title} at {time}."`

**Never invent a datetime.** If missing → return clarify string:
`"When should I remind you?"`

Validation:
```python
if not dt:
    return "When should I remind you?"
try:
    datetime.fromisoformat(iso_datetime)
except ValueError:
    return f"Couldn't parse the time for \"{title}\"."
```

## create_calendar_event

**Required params:** `title` (str), `start` (ISO 8601), `end` (ISO 8601)

AppleScript target: Calendar.app → calendar "Home"

Date format for AppleScript: same as reminders (`"%A, %B %d, %Y at %I:%M %p"`)

Reply format: `"Added {title} {start_time}–{end_time}."`

**Never invent start/end times.** If either missing → clarify:
`"What time does it start and end?"`

**Ambiguity rule:** If user says "add robotics practice tomorrow" with no time,
router should return `intent: "clarify"` — not guess 00:00.

## set_alarm

**Required params:** `time` ("HH:MM")

**Limitation:** macOS Clock.app has no AppleScript dictionary. Cannot set a real
alarm programmatically.

**Workaround (current):** Create a Reminder titled "⏰ Alarm" at the specified time.
Reply: `"Set an alarm reminder for {time}. It'll ping you on all your Apple devices."`

**iOS note:** On iOS, `UNUserNotificationCenter` can schedule local notifications
but cannot create Clock.app alarms directly. Shortcuts app can create alarms —
if Shortcuts integration is added later, update `applescript_executor.py` to call
`shortcuts run SetAlarm --input-string "HH:MM"` instead.

Document the limitation to users if they expect a native alarm sound.

## Simulation Mode

When running outside macOS (CI, demo laptop, development):
- Wrap AppleScript calls in try/except.
- If `osascript` not available, return a simulated success string.
- Tag simulation path with `# SIMULATED` comment.

Example:
```python
import shutil
APPLESCRIPT_AVAILABLE = shutil.which("osascript") is not None

def create_reminder(title: str, iso_datetime: str) -> str:
    # ... parse datetime ...
    if not APPLESCRIPT_AVAILABLE:
        return f"[DEMO] Done. Reminding you to {title} at {dt.strftime('%-I:%M %p')}."
    _run(f"tell application \"Reminders\" ...")
    return f"Done. Reminding you to {title} at {dt.strftime('%-I:%M %p')}."
```

## Timezone Handling

MVP assumes local Mac timezone. ISO 8601 datetimes without timezone offset are
treated as local time. Do not add timezone conversion until user timezone storage
is implemented.

## Testing

```bash
# Reminder
curl -X POST http://localhost:8000/message \
  -d '{"text": "Remind me to submit my physics lab tonight at 8"}'

# Calendar event
curl -X POST http://localhost:8000/message \
  -d '{"text": "Add robotics practice tomorrow from 4 to 6"}'

# Alarm
curl -X POST http://localhost:8000/message \
  -d '{"text": "Set an alarm for 7 AM"}'

# Clarify path (no time)
curl -X POST http://localhost:8000/message \
  -d '{"text": "Remind me to call mom"}'
```

## Definition of Done

- [ ] create_reminder: validates datetime, creates Reminder, returns confirmation.
- [ ] create_calendar_event: validates start+end, creates Calendar event.
- [ ] set_alarm: creates Reminder fallback, clearly documents limitation.
- [ ] Clarify returned when required params missing.
- [ ] Simulation path works when osascript unavailable.
- [ ] `ruff check .` passes.
