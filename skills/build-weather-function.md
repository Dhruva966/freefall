# Skill: build-weather-function

Build or update the weather lookup function.

## Relevant Files

- `mac-backend/weather_service.py` — OpenWeatherMap forecast fetcher
- `mac-backend/config.py` — OWM_API_KEY, OWM_BASE constants
- `mac-backend/main.py` — calls `wx.get_weather(when=when)`
- `mac-backend/server.py` — same executor path

## Current Implementation

`weather_service.py` calls OpenWeatherMap `/forecast` endpoint (5-day, 3-hour
intervals, 16 slots). Picks the first slot matching target date. Returns a string
like: `"Friday 2 PM: 68°F (feels 65°F), Partly cloudy."`

City is hardcoded to `"San Francisco"` — v2 should use user location.

## HTTPS / ATS Rule

**Always use HTTPS weather API endpoints.**

`OWM_BASE = "https://api.openweathermap.org/data/2.5"` — already correct.

If you ever move weather calls into the iOS Swift app:
- Keep HTTPS. Never switch to HTTP.
- Never add `NSAllowsArbitraryLoads` to Info.plist.
- If a specific domain needs an exception, use `NSExceptionDomains` scoped to
  that domain only — document the reason in a comment.

## API Key Rules

- Never hardcode `OWM_API_KEY` in source.
- Load from environment: `os.environ.get("OWM_API_KEY", "")`.
- Add to `.env` (gitignored). Add placeholder to `.env.example`.
- If key is missing or empty, return simulated weather response instead of crashing.

## Graceful Failure

All network calls wrapped in try/except. On any failure:
```python
return "Can't reach weather right now. Try again in a moment."
```

Never surface raw exception messages or stack traces to the user.

## Simulated Response (demo mode)

When `OWM_API_KEY` is empty or `DEMO_MODE=true`:
```python
DEMO_WEATHER = {
    "today": "Today: 72°F (feels 70°F), Sunny. Perfect for being outside.",
    "tomorrow": "Tomorrow: 65°F (feels 62°F), Partly cloudy.",
}
```
Return from `DEMO_WEATHER` dict keyed by `when` param. Fall back to "today" value
for ISO date strings.

## Extending to User Location

To support user-specific city (v2):
1. Store city preference per sender handle in a simple JSON file or SQLite table.
2. Pass `city` param to `get_weather()`.
3. Default to config city if not set.
4. Never use GPS/location APIs — ask user "What city are you in?" on first weather
   request.

## Testing

```bash
# With real key in .env
curl -X POST http://localhost:8000/message \
  -d '{"text": "What'\''s the weather tomorrow?"}'

# Expected: natural forecast string
```

Manual test without key: set `OWM_API_KEY=` empty in .env, verify simulated
response returns correctly.

## Definition of Done

- [ ] HTTPS endpoint only.
- [ ] API key loaded from environment, not hardcoded.
- [ ] Graceful failure message on network error.
- [ ] Simulated response when key missing.
- [ ] "today" and "tomorrow" both tested.
- [ ] `ruff check .` passes.
