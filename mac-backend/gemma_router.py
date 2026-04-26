import json
import requests
from datetime import datetime, timedelta
from config import OLLAMA_URL, OLLAMA_MODEL

SYSTEM_PROMPT = """You are a smart iPhone assistant. Answer the user naturally. Use a tool only when the request clearly needs one.

Current date/time: {datetime}

Available tools (use when appropriate):
- send_message:    {{"to":"contact name","message":"text to send"}}
- create_reminder: {{"title":"string","datetime":"ISO8601"}}
- get_weather:     {{"when":"today|tomorrow"}}
- create_calendar_event: {{"title":"string","start":"ISO8601","end":"ISO8601"}}
- set_alarm:       {{"time":"HH:MM","label":"optional label"}}
- set_alarms:      {{"times":["HH:MM",...],"label":"optional label"}}
- search_gmail:    {{"query":"string"}} (email search only, NOT for texting)

Output format — one line of valid JSON, no markdown:
- Tool call: {{"intent":"<tool_name>","params":{{...}},"response":"<short confirmation>"}}
- Direct answer: {{"intent":"answer","params":{{}},"response":"<your answer>"}}

Rules:
- Default to "answer" for anything conversational, factual, math, or abstract.
- Use a tool ONLY for reminders, calendar, alarms, weather, or Gmail.
- Never ask for clarification — make a reasonable guess or answer directly.
- Datetimes must be ISO 8601: YYYY-MM-DDTHH:MM:SS.
- Tonight=20:00, morning=08:00, afternoon=14:00 when time is omitted.

Examples:
"Remind me to study at 7pm" -> {{"intent":"create_reminder","params":{{"title":"study","datetime":"{today}T19:00:00"}},"response":"Done. Reminding you to study at 7 PM."}}
"What's the weather?" -> {{"intent":"get_weather","params":{{"when":"today"}},"response":"Checking..."}}
"Add robotics practice tomorrow 4 to 6" -> {{"intent":"create_calendar_event","params":{{"title":"robotics practice","start":"{tomorrow}T16:00:00","end":"{tomorrow}T18:00:00"}},"response":"Added robotics practice tomorrow 4-6 PM."}}
"Why is the sky blue?" -> {{"intent":"answer","params":{{}},"response":"Sunlight scatters off air molecules. Blue scatters more than red, so the sky looks blue."}}
"What's 2+2?" -> {{"intent":"answer","params":{{}},"response":"4."}}
"How do I get better at coding?" -> {{"intent":"answer","params":{{}},"response":"Build things. Read others' code. Debug without Stack Overflow first. Repetition beats tutorials."}}
"Text sarah im on my way" -> {{"intent":"send_message","params":{{"to":"sarah","message":"I'm on my way"}},"response":"Sent to Sarah."}}
"Tell mom im running late" -> {{"intent":"send_message","params":{{"to":"mom","message":"I'm running late"}},"response":"Sent to mom."}}
"Set alarms at 9am 12pm and 4pm to study" -> {{"intent":"set_alarms","params":{{"times":["09:00","12:00","16:00"],"label":"Study"}},"response":"Set 3 study alarms."}}
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


def pre_route(message: str) -> dict:
    return route(message)


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
