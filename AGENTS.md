# AGENTS.md — Free Fall

Free Fall is a privacy-first AI assistant that runs locally on a Mac and responds
to iMessage/SMS texts. Users text a contact named "Free Fall." The Mac polls
chat.db, routes intent through a local LLM (Gemma via Ollama), executes actions
via AppleScript, and replies back through Messages.app.

There is also a SwiftUI iOS companion app with a mock router for demo/testing.

---

## Repo Layout

```
freefall/
├── AGENTS.md                    ← you are here
├── bot.py                       ← legacy poller (pre mac-backend, ignore for new work)
├── db.py                        ← legacy chat.db helpers
├── send.py                      ← legacy AppleScript sender
├── functions.py                 ← legacy NLP matcher
├── llm.py                       ← legacy Mistral stub
├── debug.py                     ← legacy debug util
│
├── mac-backend/                 ← ACTIVE Python backend
│   ├── message_monitor.py       ← polls chat.db, dispatches messages
│   ├── main.py                  ← intent dispatcher (calls router + executor)
│   ├── gemma_router.py          ← Gemma3 via Ollama → intent JSON
│   ├── applescript_executor.py  ← AppleScript: send iMessage, reminders, calendar, alarm
│   ├── weather_service.py       ← OpenWeatherMap forecast
│   ├── server.py                ← FastAPI HTTP endpoint (POST /message)
│   ├── config.py                ← env vars / constants (DO NOT commit secrets here)
│   └── requirements.txt         ← fastapi, uvicorn, requests, httpx
│
├── FreeFall/FreeFall/           ← ACTIVE SwiftUI iOS app
│   ├── Views/ChatView.swift     ← chat UI + ChatViewModel
│   ├── Views/MessageBubble.swift← bubble component + ChatMessage model
│   ├── Views/TypingIndicator.swift
│   ├── Model/IntentResult.swift ← Intent enum, IntentParams, IntentResult
│   └── Model/MessageRouting.swift ← MessageRouting protocol + MockMessageRouter
│
├── skills/                      ← agent skill files for this project
└── docs/                        ← architecture and registry docs
```

**New work goes in `mac-backend/` (Python) or `FreeFall/FreeFall/` (Swift). The
root-level `.py` files are legacy — do not extend them.**

---

## MVP Goal

1. User texts Free Fall contact → Mac receives iMessage.
2. Gemma (local, on-device) parses intent → JSON.
3. AppleScript executes action (reminder, calendar event, alarm, weather lookup).
4. Short natural-language reply sent back via Messages.app.
5. iOS SwiftUI app shows same interaction using MockMessageRouter (demo mode).

**First five intents:** `create_reminder`, `get_weather`, `create_calendar_event`,
`set_alarm`, `search_gmail`.

---

## Architecture

```
User iMessage
  → chat.db (polled every 1.5s by message_monitor.py)
  → main.py dispatcher
  → gemma_router.py → Ollama (gemma3:1b) → intent JSON
  → applescript_executor.py / weather_service.py
  → AppleScript reply via Messages.app
  → User receives iMessage
```

HTTP path (for testing without iMessage):
```
POST /message  →  server.py  →  same router + executor chain
```

iOS path (demo):
```
ChatView → MockMessageRouter → ActionExecutor (simulated) → reply bubble
```

---

## Build Commands

### Mac backend
```bash
cd mac-backend
pip install -r requirements.txt

# Start iMessage polling bot
python message_monitor.py

# Start HTTP test server
python server.py
# or: uvicorn server:app --reload --port 8000
```

### iOS app
Open `FreeFall/FreeFall.xcodeproj` (or `.xcworkspace`) in Xcode.
Build with ⌘B. Run on simulator with ⌘R. No external package manager needed.

### Ollama (required for mac-backend)
```bash
brew install ollama
ollama pull gemma3:1b
ollama serve   # runs on localhost:11434
```

---

## Test Commands

No test suite exists yet. When adding tests:

### Python
```bash
cd mac-backend
pytest tests/ -v
```

### Swift
Run unit tests in Xcode with ⌘U.

Until tests exist, manually verify the end-to-end loop:
```bash
# Curl the HTTP endpoint
curl -X POST http://localhost:8000/message \
  -H "Content-Type: application/json" \
  -d '{"text": "Remind me to submit my physics lab tonight at 8"}'
```

Expected: JSON with `reply` field containing natural-language confirmation.

---

## Lint / Type Check

### Python
```bash
cd mac-backend
ruff check .          # linter
mypy .                # type checker (add to requirements.txt if needed)
```

### Swift
Xcode build warnings count as lint. Fix all warnings before marking a task done.

---

## Code Style

- Python: PEP 8, type hints on all function signatures, no bare `except`.
- Swift: SwiftUI idioms, `@MainActor` on ViewModels, `async/await` for network.
- Keep modules separate: no UI code in router, no AppleScript in weather service.
- Short, readable functions. No abstraction beyond what the task needs.
- No docstrings for obvious functions. One-line comment only when the WHY is
  non-obvious.

---

## Environment Variables

**Never hardcode secrets.** Use `.env` (never commit) and load with `python-dotenv`
or read from environment.

Required env vars for `mac-backend`:
```
OWM_API_KEY=       # OpenWeatherMap free tier key
OLLAMA_URL=        # default: http://localhost:11434/api/generate
OLLAMA_MODEL=      # default: gemma3:1b
FREEFALL_HANDLE=   # Apple ID or phone number logged into Messages.app
```

See `.env.example` for placeholder values. Copy to `.env` and fill in.

`config.py` should read from `os.environ`, not hardcode values.

---

## Security Rules

1. Never commit `.env`. Verify `.gitignore` contains `.env` and `.env.local`.
2. Never log API keys, OAuth tokens, or phone numbers.
3. `config.py` must not contain real credentials — use env vars.
4. Gmail OAuth tokens stored in memory only; never written to disk in MVP.
5. `chat.db` contains private iMessage data — never log message content in
   production, only in local debug mode.
6. Use dev/demo credentials by default. Real Gmail access requires explicit setup.

---

## iOS / iMessage Integration Cautions

- **No official Apple API** for chat.db or AppleScript iMessage control. Apple can
  change this without notice.
- `message_monitor.py` requires Full Disk Access for Terminal in System Settings.
- `applescript_executor.py` requires Automation permission for Terminal → Messages.
- Messages.app must stay open. Mac sleep = bot stops. Set sleep to Never.
- AppleScript `set_alarm` cannot control Clock.app (no AS dictionary). Current
  workaround: creates a Reminder instead. Document this to users.
- Group chat `handle_id` logic differs from 1:1. MVP targets 1:1 only.

---

## Weather API / ATS Caution

`weather_service.py` uses `https://api.openweathermap.org` (HTTPS). This is
correct and safe for iOS ATS (App Transport Security).

If you ever add a weather call inside the iOS Swift app:
- Always use HTTPS endpoints.
- Never add an `NSAllowsArbitraryLoads` Info.plist exception — it disables ATS
  globally and will cause App Store rejection.
- If an HTTP-only endpoint is truly required, add a scoped `NSExceptionDomains`
  entry for that domain only and document why.

---

## Function-Calling Rules

Router output must be valid JSON matching this schema:
```json
{
  "intent": "<intent_name>",
  "params": { "<key>": "<value>" },
  "response": "<short natural language confirmation or clarification>"
}
```

Rules:
- Return only valid JSON from the router. No prose, no markdown fences.
- Do not invent missing dates, times, or locations. Ask to clarify instead.
- If required params are absent: return `intent: "clarify"` with a question.
- Prefer action intent over general chat intent.
- `intent` must be one of: `create_reminder`, `get_weather`, `create_calendar_event`,
  `set_alarm`, `search_gmail`, `clarify`, `unknown`.
- All datetimes in ISO 8601 format (`YYYY-MM-DDTHH:MM:SS`).

---

## Agent-Driven Development — MANDATORY

**This is the most important section. Read it first. Follow it on every task.**

Free Fall is built using agent and sub-agent driven development. This is not
optional. Doing work serially when it can be parallelized is waste. Doing
exploration inline when a sub-agent can do it is waste. Every task must be
decomposed and delegated as aggressively as possible.

### RULE 1: Decompose before you write a single line of code

Before touching any file, break the task into independent sub-tasks. Ask:
- What can be researched/explored in parallel right now?
- What can be implemented in parallel once exploration is done?
- What requires sequential ordering (A must finish before B)?

Only sequential dependencies justify serial execution. Everything else runs in
parallel. No exceptions.

### RULE 2: Spawn sub-agents for all exploration

Do NOT read files inline to understand the codebase when a sub-agent can do it.
Spawn an Explore sub-agent for any question that spans more than 2-3 files:
- "Where is X defined?" → Explore agent
- "Which files reference Y?" → Explore agent
- "What's the current state of module Z?" → Explore agent

This keeps the main context clean and focused on decisions, not discovery.

### RULE 3: Parallelize all independent work

If a task has 3 independent pieces (e.g., update router + update executor +
update tests), spawn 3 sub-agents simultaneously. Do not do them one at a time.

Use the Agent tool with `run_in_background: true` for work you don't need
immediately. Collect results when all agents complete, then integrate.

### RULE 4: Use /codex for all discrete build tasks

Use `/codex` for any self-contained task that doesn't require live conversation
context. This preserves Claude Code credits for interactive debugging only.

**Always use `/codex` for:**
- Generating or updating AGENTS.md, docs, or skill files
- Adding a new function/intent end-to-end (router + executor + registry + tests)
- Refactoring a self-contained module
- Writing or updating tests
- **ALL code reviews — no exceptions**
- Any task where the full requirement fits in a single prompt

**Use Claude Code (interactive) only for:**
- Active debugging with live error output you are reading together
- Multi-turn investigation where prior conversation state matters
- Architectural decisions requiring back-and-forth

### RULE 5: Sub-agent task template

Every sub-agent prompt must include:
1. What this sub-agent is responsible for (single, bounded scope)
2. Which files it should read (exact paths)
3. What it should produce (exact output format)
4. What it must NOT do (scope boundary)
5. Whether to write code or just research

Never give a sub-agent open-ended instructions like "fix the project." Bounded
scope = predictable output = efficient parallel execution.

### RULE 6: Never do research that a sub-agent can do

If you find yourself reading more than 3 files to understand something before
writing code, stop. Spawn an Explore sub-agent instead. Use its output to
inform your implementation. Do not let exploration bloat the main context.

### RULE 7: Integration is done by the orchestrator, not sub-agents

Sub-agents research and implement bounded pieces. The orchestrating agent
(main context) integrates outputs, resolves conflicts, and writes the final
coherent result. Sub-agents do not coordinate with each other directly.

### Parallel Execution Patterns for This Repo

**Adding a new intent (e.g., play_music):**
```
[PARALLEL - spawn simultaneously]
  Sub-agent A: Update gemma_router.py — add to system prompt + examples
  Sub-agent B: Update applescript_executor.py — implement action function
  Sub-agent C: Update IntentResult.swift + MockMessageRouter — Swift model

[SEQUENTIAL - after all three complete]
  Orchestrator: Update main.py + server.py _execute() with results from A+B
  Orchestrator: Update docs/function-registry.md
  Orchestrator: Run ruff check . and fix errors
```

**Debugging a broken intent:**
```
[PARALLEL - spawn simultaneously]
  Explore agent A: Read gemma_router.py + system prompt for this intent
  Explore agent B: Read applescript_executor.py for this intent's function
  Explore agent C: Curl the /message endpoint and capture raw response

[SEQUENTIAL - after all three complete]
  Orchestrator: Diagnose based on combined output, write targeted fix
```

**Pre-demo verification:**
```
[PARALLEL - spawn simultaneously]
  Sub-agent A: Curl all 5 intents, report pass/fail
  Sub-agent B: Check config.py for hardcoded secrets
  Sub-agent C: Verify DEMO_MODE responses are realistic
  Sub-agent D: Read MockMessageRouter, verify all 5 demo phrases covered
```

---

## When to Use Codex vs Claude Code

(See RULE 4 above for the full decision tree.)

Quick reference:
- `/codex` → any discrete build task, docs, tests, code review
- Claude Code → active debugging, multi-turn investigation only

---

## Agent Workflow Checklist

Every agent task must follow this sequence:

1. **Read `AGENTS.md`** (this file) — especially the Agent-Driven Development section.
2. **Decompose** — list all sub-tasks before starting. Identify parallel vs sequential.
3. **Spawn Explore sub-agents** for any codebase discovery spanning 3+ files.
4. **Spawn parallel sub-agents** for all independent implementation work.
5. **Identify relevant skill files** in `skills/` and read them.
6. **Integrate** sub-agent outputs in the main context.
7. **Make targeted edits** — smallest clean change that solves the task.
8. **Add or update tests** when possible.
9. **Run lint** (`ruff check .`) and type check (`mypy .`) for Python; build for Swift.
10. **Fix all errors** before finishing.
11. **Summarize:**
    - Files changed
    - What was implemented
    - How it was tested
    - Sub-agents spawned and what each produced
    - Remaining risks or TODOs

---

## Definition of Done

A task is done when:
- [ ] Code is in the correct module (`mac-backend/` or `FreeFall/FreeFall/`).
- [ ] No secrets hardcoded.
- [ ] Python: `ruff check .` passes. Swift: project builds with no warnings.
- [ ] New function added to `docs/function-registry.md` if applicable.
- [ ] Demo/simulated path works even when real integration is unavailable.
- [ ] Summary written with files changed, test approach, and open TODOs.
