# Skill: security-and-env

Handle secrets and environment variables safely across the Free Fall codebase.

## The Problem

`mac-backend/config.py` currently hardcodes:
- `OWM_API_KEY = "YOUR_OWM_KEY_HERE"` — placeholder but pattern is wrong
- `FREEFALL_HANDLE = "vutukurydhruva@gmail.com"` — real Apple ID committed to repo

This must be fixed before any production or shared use.

## Rules

1. **Never commit secrets.** API keys, OAuth tokens, Apple IDs, phone numbers.
2. **Never log secrets.** No `print(api_key)`, no key in exception messages.
3. **`.env` is gitignored.** Always. Verify with `git check-ignore -v .env`.
4. **`.env.example` has placeholder values only.** Use `YOUR_KEY_HERE` style.
5. Use dev/test credentials by default. Never connect to production data unless
   explicitly configured by the user.

## Where Secrets Live

| Secret | Where to store | File |
|---|---|---|
| OWM_API_KEY | `.env` | `mac-backend/.env` |
| FREEFALL_HANDLE | `.env` | `mac-backend/.env` |
| Gmail credentials | gitignored file | `mac-backend/credentials.json` |
| Gmail token | gitignored file | `mac-backend/token.json` |

## config.py Pattern

Read from environment, never hardcode:

```python
import os

OWM_API_KEY   = os.environ.get("OWM_API_KEY", "")
OWM_BASE      = os.environ.get("OWM_BASE", "https://api.openweathermap.org/data/2.5")
OLLAMA_URL    = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/generate")
OLLAMA_MODEL  = os.environ.get("OLLAMA_MODEL", "gemma3:1b")
FREEFALL_HANDLE = os.environ.get("FREEFALL_HANDLE", "")
POLL_INTERVAL = float(os.environ.get("POLL_INTERVAL", "1.5"))
CHAT_DB       = os.environ.get(
    "CHAT_DB",
    os.path.expanduser("~/Library/Messages/chat.db")
)
DEMO_MODE     = os.environ.get("DEMO_MODE", "false").lower() == "true"
```

## .env File (gitignored)

```bash
# mac-backend/.env — DO NOT COMMIT
OWM_API_KEY=your_real_key_here
FREEFALL_HANDLE=your_apple_id_or_phone@example.com
DEMO_MODE=false
```

Load with python-dotenv in `config.py`:
```python
from dotenv import load_dotenv
load_dotenv()   # reads mac-backend/.env if present
```

Add `python-dotenv` to `requirements.txt`.

## .env.example File (committed)

```bash
# mac-backend/.env.example — copy to .env and fill in real values
OWM_API_KEY=YOUR_OWM_API_KEY_HERE
FREEFALL_HANDLE=YOUR_APPLE_ID_OR_PHONE_HERE
OLLAMA_URL=http://localhost:11434/api/generate
OLLAMA_MODEL=gemma3:1b
DEMO_MODE=false
```

## .gitignore Additions

Ensure `.gitignore` at repo root contains:
```
.env
.env.local
mac-backend/.env
mac-backend/credentials.json
mac-backend/token.json
__pycache__/
*.pyc
*.db
```

## AppleScript Injection Risk

User input passed into AppleScript must be escaped. Current `send_imessage`
escapes double quotes:
```python
escaped = text.replace('"', '\\"')
```

This is necessary but insufficient for adversarial input. Before adding any new
AppleScript that injects user-provided strings:
- Escape `"`, `\`, and newlines.
- Consider parameterized AppleScript via `osascript` file input instead of
  inline string interpolation for complex cases.

## Chat.db Privacy

`chat.db` contains all iMessage history on the Mac. Rules:
- Never log raw message text in production mode.
- `print()` of message content is acceptable in local debug mode only.
- Never write message content to a file or external service.
- `DEMO_MODE=true` should not disable privacy protections.

## Definition of Done

- [ ] `config.py` reads all values from `os.environ`, zero hardcoded secrets.
- [ ] `python-dotenv` added to `requirements.txt`.
- [ ] `.env.example` committed with placeholder values.
- [ ] `.gitignore` covers `.env`, `credentials.json`, `token.json`, `__pycache__`, `*.pyc`.
- [ ] `git status` shows no secrets in staged files.
- [ ] `ruff check .` passes.
