# Function Registry — Free Fall

All assistant functions, their schemas, example inputs/outputs, and implementation status.

---

## create_reminder

**Description:** Create a reminder in Reminders.app that fires at a specific time.

**Required params:**
- `title` (str) — reminder text
- `datetime` (ISO 8601 str) — e.g., `"2026-04-25T20:00:00"`

**Optional params:** none

**Example user messages:**
- "Remind me to submit my physics lab tonight at 8."
- "Remind me to take my meds at 9 PM."
- "Set a reminder for the robotics meeting at 3:30."

**Example JSON output:**
```json
{
  "intent": "create_reminder",
  "params": {
    "title": "submit physics lab",
    "datetime": "2026-04-25T20:00:00"
  },
  "response": "Done. Reminding you to submit your physics lab at 8:00 PM."
}
```

**Success response:** `"Done. Reminding you to {title} at {time}."`

**Clarification response (missing time):** `"When should I remind you?"`

**Failure response:** `"Couldn't create that reminder. Try again?"`

**Status:** ✅ REAL — AppleScript → Reminders.app

---

## get_weather

**Description:** Get current or forecast weather for a city.

**Required params:**
- `when` (str) — `"today"`, `"tomorrow"`, or ISO 8601 date (`"2026-04-26"`)

**Optional params:**
- `city` (str) — defaults to config city (currently "San Francisco")

**Example user messages:**
- "What's the weather tomorrow morning?"
- "Is it going to rain today?"
- "Weather this weekend?"

**Example JSON output:**
```json
{
  "intent": "get_weather",
  "params": {
    "when": "tomorrow"
  },
  "response": "Checking tomorrow's weather..."
}
```

**Success response:** `"Friday 2 PM: 68°F (feels 65°F), Partly cloudy."`

**Clarification response:** n/a — `when` defaults to "today" if omitted

**Failure response:** `"Can't reach weather right now. Try again in a moment."`

**Status:** ✅ REAL — OpenWeatherMap API (HTTPS). Falls back to simulated if key missing.

---

## create_calendar_event

**Description:** Add an event to Calendar.app (calendar "Home").

**Required params:**
- `title` (str) — event name
- `start` (ISO 8601 str) — start datetime
- `end` (ISO 8601 str) — end datetime

**Optional params:** none

**Example user messages:**
- "Add robotics practice tomorrow from 4 to 6."
- "Schedule a dentist appointment Friday at 2 PM for an hour."
- "Block off Saturday morning 9 to 11 for studying."

**Example JSON output:**
```json
{
  "intent": "create_calendar_event",
  "params": {
    "title": "robotics practice",
    "start": "2026-04-26T16:00:00",
    "end": "2026-04-26T18:00:00"
  },
  "response": "Added robotics practice 4:00–6:00 PM tomorrow."
}
```

**Success response:** `"Added {title} {start_time}–{end_time}."`

**Clarification response (missing times):** `"What time does it start and end?"`

**Failure response:** `"Couldn't add that to your calendar. Try again?"`

**Status:** ✅ REAL — AppleScript → Calendar.app

---

## search_gmail

**Description:** Search Gmail for a specific email by keyword, sender, or subject.

**Required params:**
- `query` (str) — search string (supports Gmail operators: `from:`, `subject:`, free text)

**Optional params:** none

**Example user messages:**
- "Find the UCLA Fast Track email."
- "Did I get anything from my advisor this week?"
- "Search for the Zoom link email."

**Example JSON output:**
```json
{
  "intent": "search_gmail",
  "params": {
    "query": "UCLA Fast Track"
  },
  "response": "Searching your Gmail..."
}
```

**Success response:** `"Found it. The UCLA Fast Track email mentions a Zoom info session on May 3rd."`

**Clarification response (vague query):** `"What should I search for? Give me a keyword or sender name."`

**Failure response:** `"Couldn't search Gmail right now. Try again in a moment."`

**Status:** 🟡 SIMULATED — returns canned demo response. Real OAuth path documented in `skills/build-gmail-search-function.md`.

---

## set_alarm

**Description:** Set an alarm for a specific time.

**Required params:**
- `time` (str, "HH:MM") — e.g., `"07:00"`

**Optional params:** none

**Example user messages:**
- "Set an alarm for 7 AM."
- "Wake me up at 6:30."
- "Alarm at 8 tomorrow morning."

**Example JSON output:**
```json
{
  "intent": "set_alarm",
  "params": {
    "time": "07:00"
  },
  "response": "Opening alarm for 7 AM — tap Set to confirm."
}
```

**Success response:** `"Set an alarm reminder for 7:00 AM. It'll ping you on all your Apple devices."`

**Clarification response (missing time):** `"What time should I set the alarm for?"`

**Failure response:** `"Couldn't set the alarm. Try saying the time like '7 AM' or '6:30'."`

**Status:** 🟡 PARTIAL — creates a Reminder as alarm substitute. Clock.app has no AppleScript dictionary. Native alarm via Shortcuts (`shortcuts run SetAlarm`) is planned for v2.

---

## fallback

**Description:** Returned when no intent matches or input is too ambiguous.

**Required params:** none

**Optional params:** none

**Example triggers:**
- "Hey what's up"
- "lol"
- Garbled or very short messages

**Example JSON output:**
```json
{
  "intent": "unknown",
  "params": {},
  "response": "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\""
}
```

**Response:** `"I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\""`

**Status:** ✅ REAL — always returns helpful suggestion.

---

## Status Key

- ✅ REAL — live integration working
- 🟡 SIMULATED — returns demo response, real path documented but not wired
- 🟡 PARTIAL — works with limitations (documented)
- ❌ NOT STARTED — not yet implemented
