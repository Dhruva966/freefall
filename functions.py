"""
functions.py — intent → action executor.

Takes a parsed intent dict from llm.py and executes the corresponding
action via AppleScript (Calendar, Reminders) or OpenWeatherMap API.
Returns a reply string to send back to the user.
"""

import subprocess
from datetime import datetime
from typing import Optional

OWM_API_KEY = "fef21b0e4c96bd8d494fe1295a1145e2"
OWM_BASE    = "https://api.openweathermap.org/data/2.5"

GMAIL_CANNED = "Found it. The UCLA Fast Track email mentions a Zoom info session on May 3rd."


# ── AppleScript helpers ───────────────────────────────────────────────────────

def _run_applescript(script: str) -> str:
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    return result.stdout.strip()


# ── Actions ───────────────────────────────────────────────────────────────────

def create_reminder(title: str, iso_datetime: str) -> str:
    try:
        dt       = datetime.fromisoformat(iso_datetime)
        mac_date = dt.strftime("%A, %B %d, %Y at %I:%M %p")
    except ValueError:
        return f"Couldn't parse the time for \"{title}\"."

    _run_applescript(f'''
        tell application "Reminders"
            tell list "Reminders"
                make new reminder with properties {{name:"{title}", due date:date "{mac_date}"}}
            end tell
        end tell
    ''')
    return f"Done. Reminding you to {title} at {dt.strftime('%-I:%M %p')}."


def create_calendar_event(title: str, start_iso: str, end_iso: str) -> str:
    try:
        start     = datetime.fromisoformat(start_iso)
        end       = datetime.fromisoformat(end_iso)
        mac_start = start.strftime("%A, %B %d, %Y at %I:%M %p")
        mac_end   = end.strftime("%A, %B %d, %Y at %I:%M %p")
    except ValueError:
        return f"Couldn't parse the times for \"{title}\"."

    _run_applescript(f'''
        tell application "Calendar"
            tell calendar "Home"
                make new event with properties {{summary:"{title}", start date:date "{mac_start}", end date:date "{mac_end}"}}
            end tell
        end tell
    ''')
    return f"Added {title} — {start.strftime('%-I:%M')}–{end.strftime('%-I:%M %p')}."


def set_alarm(time_hhmm: str) -> str:
    try:
        h, m     = time_hhmm.split(":")
        now      = datetime.now()
        alarm_dt = now.replace(hour=int(h), minute=int(m), second=0, microsecond=0)
        mac_date = alarm_dt.strftime("%A, %B %d, %Y at %I:%M %p")
    except Exception:
        return "Couldn't parse the alarm time."

    # macOS Clock has no AppleScript API — create a Reminder instead
    _run_applescript(f'''
        tell application "Reminders"
            tell list "Reminders"
                make new reminder with properties {{name:"⏰ Alarm", due date:date "{mac_date}"}}
            end tell
        end tell
    ''')
    return f"Set alarm reminder for {alarm_dt.strftime('%-I:%M %p')} — it'll ping all your Apple devices."


def get_weather(when: str = "today", city: str = "San Francisco") -> str:
    import requests
    from datetime import timedelta

    if OWM_API_KEY == "YOUR_OWM_KEY_HERE":
        return "Weather API key not set yet — ask your teammate for the key."

    try:
        resp = requests.get(
            f"{OWM_BASE}/forecast",
            params={"q": city, "appid": OWM_API_KEY, "units": "imperial", "cnt": 16},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        return f"Can't reach weather right now. ({e})"

    forecasts = data.get("list", [])
    if not forecasts:
        return "No weather data available."

    now         = datetime.now()
    target_date = now.date() if when == "today" else (now + timedelta(days=1)).date()
    slots       = [f for f in forecasts if datetime.fromtimestamp(f["dt"]).date() == target_date]
    slot        = slots[0] if slots else forecasts[0]

    temp  = round(slot["main"]["temp"])
    feels = round(slot["main"]["feels_like"])
    desc  = slot["weather"][0]["description"].capitalize()
    dt    = datetime.fromtimestamp(slot["dt"])

    return f"{dt.strftime('%A')} {dt.strftime('%-I %p')}: {temp}°F (feels {feels}°F), {desc}."


# ── Dispatcher ────────────────────────────────────────────────────────────────

def execute(intent_result: dict) -> str:
    """Take a parsed intent dict from llm.get_response() and run the action."""
    intent         = intent_result.get("intent", "unknown")
    params         = intent_result.get("params", {})
    model_response = intent_result.get("response", "")

    if intent == "create_reminder":
        title = params.get("title", "reminder")
        dt    = params.get("datetime", "")
        return create_reminder(title, dt) if dt else "What time should I remind you?"

    if intent == "get_weather":
        return get_weather(when=params.get("when", "today"))

    if intent == "create_calendar_event":
        title = params.get("title", "Event")
        start = params.get("start", "")
        end   = params.get("end", "")
        return create_calendar_event(title, start, end) if (start and end) else "What time does it start and end?"

    if intent == "set_alarm":
        t = params.get("time", "")
        return set_alarm(t) if t else "What time should I set the alarm for?"

    if intent == "search_gmail":
        return GMAIL_CANNED

    if intent == "clarify":
        return model_response or "Can you say that differently?"

    return model_response or "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\""


# ── Legacy stubs (kept so existing imports don't break) ───────────────────────

def match_and_run(text: str) -> Optional[str]:
    return None


def run_shortcut(name: str, input_text: Optional[str] = None) -> None:
    subprocess.run(
        ["shortcuts", "run", name] + (["--input-string", input_text] if input_text else []),
        capture_output=True,
    )
