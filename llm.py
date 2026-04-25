"""
llm.py — Gemma 3 1B via Ollama.

Returns a parsed intent dict:
  {"intent": "create_reminder", "params": {"title": "study", "datetime": "..."}, "response": "..."}
"""

import json
import requests
from datetime import datetime, timedelta
from typing import Optional

OLLAMA_URL   = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "gemma3:1b"

_SYSTEM = """\
You are an iPhone assistant. Output JSON only. No prose, no markdown, no explanation.

Current date/time: {datetime}

You MUST output exactly this structure:
{{"intent":"<intent>","params":{{...}},"response":"<natural language reply>"}}

intent MUST be one of: create_reminder, get_weather, create_calendar_event, set_alarm, search_gmail, clarify, unknown
Do NOT invent new intent names.

Param schemas (use ONLY these keys):
- create_reminder:       {{"title":"string","datetime":"ISO8601"}}
- get_weather:           {{"when":"today|tomorrow"}}
- create_calendar_event: {{"title":"string","start":"ISO8601","end":"ISO8601"}}
- set_alarm:             {{"time":"HH:MM"}}
- search_gmail:          {{"query":"string"}}
- clarify:               {{}}
- unknown:               {{}}

Rules:
- datetime/start/end must be full ISO8601: {today}T19:00:00
- If user says "tonight" assume 8pm. "morning" assume 8am. "afternoon" assume 2pm.
- If time is missing from reminder or event, use intent "clarify".
- response must be a short, friendly confirmation in plain English.

Examples:
"Remind me to study at 7pm" -> {{"intent":"create_reminder","params":{{"title":"study","datetime":"{today}T19:00:00"}},"response":"Done. Reminding you to study at 7 PM."}}
"Remind me to call mom" -> {{"intent":"clarify","params":{{}},"response":"When should I remind you to call mom?"}}
"What's the weather tomorrow" -> {{"intent":"get_weather","params":{{"when":"tomorrow"}},"response":"Checking tomorrow's weather..."}}
"What's the weather" -> {{"intent":"get_weather","params":{{"when":"today"}},"response":"Checking today's weather..."}}
"Add robotics practice tomorrow 4 to 6" -> {{"intent":"create_calendar_event","params":{{"title":"robotics practice","start":"{tomorrow}T16:00:00","end":"{tomorrow}T18:00:00"}},"response":"Added robotics practice tomorrow 4-6 PM."}}
"Wake me up at 7" -> {{"intent":"set_alarm","params":{{"time":"07:00"}},"response":"Setting alarm for 7 AM."}}
"Find the UCLA email" -> {{"intent":"search_gmail","params":{{"query":"UCLA"}},"response":"Searching your email for UCLA..."}}
"Tell me a joke" -> {{"intent":"unknown","params":{{}},"response":"I can set reminders, check weather, add calendar events, set alarms, or search your email."}}
"""


def _extract_json(raw: str) -> Optional[dict]:
    start = raw.find("{")
    end   = raw.rfind("}")
    if start == -1 or end == -1:
        return None
    try:
        return json.loads(raw[start:end + 1])
    except json.JSONDecodeError:
        return None


def _fallback() -> dict:
    return {
        "intent": "unknown",
        "params": {},
        "response": "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\"",
    }


def get_response(text: str, context: Optional[str] = None, _attempt: int = 0) -> dict:
    """Send text to Gemma via Ollama. Returns parsed intent dict."""
    now      = datetime.now()
    tomorrow = now + timedelta(days=1)
    prompt   = _SYSTEM.format(
        datetime=now.isoformat(timespec="seconds"),
        today=now.strftime("%Y-%m-%d"),
        tomorrow=tomorrow.strftime("%Y-%m-%d"),
    )
    if _attempt > 0:
        prompt += "\nIMPORTANT: output valid JSON only. No other text."

    full_prompt = prompt + f'\n\nUser: "{text}"\nJSON:'

    try:
        resp = requests.post(
            OLLAMA_URL,
            json={"model": OLLAMA_MODEL, "prompt": full_prompt, "stream": False, "format": "json"},
            timeout=30,
        )
        resp.raise_for_status()
        raw = resp.json().get("response", "")
    except Exception as e:
        print(f"[llm] Ollama error: {e}")
        return _fallback()

    result = _extract_json(raw)
    if result is None and _attempt < 1:
        return get_response(text, _attempt=1)

    return result or _fallback()
