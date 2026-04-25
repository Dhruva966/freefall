import json
import re
import requests
from datetime import datetime, timedelta
from config import OLLAMA_URL, OLLAMA_MODEL

SYSTEM_PROMPT = """You are an iPhone assistant. Parse the user message and return JSON only. No prose. No markdown.

Current date/time: {datetime}

Intents: create_reminder, get_weather, create_calendar_event, set_alarm, search_gmail, clarify, unknown

Output format (one line, no markdown):
{{"intent":"<intent>","params":{{...}},"response":"<natural language confirmation>"}}

Param schemas:
- create_reminder:       {{"title":"string","datetime":"ISO8601"}}
- get_weather:           {{"when":"today|tomorrow|ISO8601_date"}}
- create_calendar_event: {{"title":"string","start":"ISO8601","end":"ISO8601"}}
- set_alarm:             {{"time":"HH:MM"}}
- search_gmail:          {{"query":"string"}}

If unclear: {{"intent":"clarify","params":{{}},"response":"<ask user to clarify>"}}
If none match: {{"intent":"unknown","params":{{}},"response":"<helpful suggestion>"}}

Examples:
"Remind me to study at 7pm" -> {{"intent":"create_reminder","params":{{"title":"study","datetime":"{today}T19:00:00"}},"response":"Done. Reminding you to study at 7 PM."}}
"What's the weather tomorrow" -> {{"intent":"get_weather","params":{{"when":"tomorrow"}},"response":"Checking tomorrow's weather..."}}
"Add robotics practice tomorrow 4 to 6" -> {{"intent":"create_calendar_event","params":{{"title":"robotics practice","start":"{tomorrow}T16:00:00","end":"{tomorrow}T18:00:00"}},"response":"Added robotics practice tomorrow 4-6 PM."}}

Rules:
- Interpret tonight as 8 PM, morning as 8 AM, and afternoon as 2 PM when the user implies a date but omits an exact time.
- All datetimes must be ISO 8601 in the form YYYY-MM-DDTHH:MM:SS.
- Return JSON only, with no prose or markdown.
- If a required time is missing for an action that needs one, return intent "clarify".
"""


def _extract_json(raw: str) -> dict | None:
    # Find first { ... last } block — handles model preamble/markdown wrapping
    start = raw.find("{")
    end = raw.rfind("}")
    if start == -1 or end == -1:
        return None
    try:
        return json.loads(raw[start:end + 1])
    except json.JSONDecodeError:
        return None


def route(message: str, attempt: int = 0) -> dict:
    now = datetime.now()
    prompt = SYSTEM_PROMPT.format(
        datetime=now.isoformat(timespec="seconds"),
        today=now.strftime("%Y-%m-%d"),
        tomorrow=(now + timedelta(days=1)).strftime("%Y-%m-%d"),
    )
    if attempt > 0:
        prompt += "\nIMPORTANT: output valid JSON only. No other text."

    full_prompt = prompt + f'\n\nUser: "{message}"\nJSON:'

    try:
        resp = requests.post(
            OLLAMA_URL,
            json={
                "model": OLLAMA_MODEL,
                "prompt": full_prompt,
                "stream": False,
                "format": "json",
            },
            timeout=30,
        )
        resp.raise_for_status()
        raw = resp.json().get("response", "")
    except Exception as e:
        print(f"[gemma_router] Ollama error: {e}")
        return _fallback()

    result = _extract_json(raw)
    if result is None and attempt < 1:
        return route(message, attempt=1)

    return result or _fallback()


def _fallback() -> dict:
    return {
        "intent": "unknown",
        "params": {},
        "response": "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\"",
    }
