# Skill: build-intent-router

Build or update the natural language → function-call router.

## Relevant Files

- `mac-backend/gemma_router.py` — Python router using Gemma3 via Ollama
- `mac-backend/main.py` — intent dispatcher (calls router, then executor)
- `mac-backend/server.py` — FastAPI HTTP endpoint
- `FreeFall/FreeFall/Model/MessageRouting.swift` — Swift protocol + MockMessageRouter
- `FreeFall/FreeFall/Model/IntentResult.swift` — Swift intent/params types

## Router Output Schema

Router must return valid JSON — one line, no markdown fences, no prose:

```json
{
  "intent": "create_reminder",
  "params": {
    "title": "submit physics lab",
    "datetime": "2026-04-25T20:00:00"
  },
  "response": "Done. Reminding you to submit your physics lab tonight at 8 PM."
}
```

Valid intents: `create_reminder`, `get_weather`, `create_calendar_event`,
`set_alarm`, `search_gmail`, `clarify`, `unknown`.

## Param Schemas

| Intent | Required params | Optional |
|---|---|---|
| create_reminder | title (str), datetime (ISO8601) | — |
| get_weather | when ("today"\|"tomorrow"\|ISO8601 date) | — |
| create_calendar_event | title (str), start (ISO8601), end (ISO8601) | — |
| set_alarm | time ("HH:MM") | — |
| search_gmail | query (str) | — |
| clarify | — | — |
| unknown | — | — |

## Critical Rules

1. **Return only valid JSON.** No preamble, no markdown, no trailing text.
2. **Never invent missing dates, times, emails, or locations.** If a required param
   is absent, return `intent: "clarify"` with a question in `response`.
3. **Prefer action intent over general chat.** "remind me" → `create_reminder`,
   not `unknown`.
4. **All datetimes in ISO 8601** (`YYYY-MM-DDTHH:MM:SS`). Use current date from
   system clock for relative times ("tonight", "tomorrow").
5. If JSON parse fails, retry once with stronger "JSON only" instruction before
   falling back to `_fallback()`.

## Python Router (gemma_router.py)

- Prompt injects current datetime and today/tomorrow dates at call time.
- `_extract_json(raw)` strips model preamble — finds first `{` to last `}`.
- Retry logic: `route(message, attempt=1)` adds `"output valid JSON only"` to prompt.
- `_fallback()` returns `intent: "unknown"` with helpful suggestion string.
- Timeout: 30s on Ollama request. Catch all exceptions → return `_fallback()`.

## Swift MockMessageRouter

MockMessageRouter in `MessageRouting.swift` is the demo/test fallback.
It matches keywords (`remind`, `weather`, `calendar`, `alarm`) and returns
hardcoded IntentResult values. It must always compile and work without network.

When building a real on-device Swift router:
- Conform to `MessageRouting` protocol.
- Return `IntentResult` — same schema as Python JSON output.
- Keep MockMessageRouter intact as demo fallback.

## Adding a New Intent

1. Add to `Intent` enum in `IntentResult.swift`.
2. Add param fields to `IntentParams` struct if needed.
3. Add to `SYSTEM_PROMPT` examples in `gemma_router.py`.
4. Add handler branch in `main.py` `_execute()` and `server.py` `_execute()`.
5. Add to MockMessageRouter keyword matching.
6. Add to `docs/function-registry.md`.

## Testing

```bash
curl -X POST http://localhost:8000/message \
  -H "Content-Type: application/json" \
  -d '{"text": "Remind me to submit my physics lab tonight at 8"}'

# Expected:
# {"reply": "Done. Reminding you to submit your physics lab at 8:00 PM."}
```

Test clarify path:
```bash
curl -X POST http://localhost:8000/message \
  -d '{"text": "Remind me to call mom"}'
# Expected: clarify response asking for time
```
