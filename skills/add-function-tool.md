# Skill: add-function-tool

Repeatable process for adding a new assistant function safely.

## When to Use

Use this skill when adding any new intent/action to Free Fall — a new shortcut,
API integration, or on-device action.

## MANDATORY: Use Sub-Agents and Parallelize

**Do not execute these steps serially.** Steps 2, 3, and 4 are fully independent
and MUST be spawned as parallel sub-agents simultaneously.

Required parallel execution pattern:
```
[SPAWN SIMULTANEOUSLY — 3 parallel sub-agents]
  Sub-agent A (router):   Update gemma_router.py system prompt + examples
  Sub-agent B (executor): Write action function in applescript_executor.py
  Sub-agent C (Swift):    Add Intent case + params to IntentResult.swift
                          + keyword branch in MockMessageRouter

[AFTER ALL 3 COMPLETE — orchestrator does these sequentially]
  Wire both main.py and server.py _execute() with outputs from A + B
  Update docs/function-registry.md
  Run ruff check . and fix errors
```

Spawning these one at a time is explicitly wrong. The three parallel agents
do not depend on each other — run them together and collect results.

**Use `/codex` for this entire workflow.** Adding a function is a discrete build
task. It does not need interactive Claude Code context.

## Step-by-Step Process

### 1. Define the function

Decide:
- **Function name** (snake_case): e.g., `play_music`, `send_message`
- **Required params**: params without which the action cannot execute
- **Optional params**: params with sensible defaults
- **Example user messages**: 3+ natural language phrasings

### 2. Update the intent schema (Python)

In `mac-backend/gemma_router.py`:
- Add to `SYSTEM_PROMPT` param schemas section.
- Add 1-2 examples showing user message → JSON output.

### 3. Update the Swift model

In `FreeFall/FreeFall/Model/IntentResult.swift`:
- Add new case to `Intent` enum (snake_case raw value matching Python intent name).
- Add any new param fields to `IntentParams` struct.

### 4. Add executor logic (Python)

In `mac-backend/applescript_executor.py` or a new service file:
- Write the function with full type hints.
- Return a string (the reply to send back to user).
- Handle all failure cases — return a friendly error string, never raise.

In `mac-backend/main.py` and `mac-backend/server.py`:
- Add `if intent == "new_intent":` branch in `_execute()`.
- Both files have `_execute()` — update both.

### 5. Add validation

Before executing:
- Check all required params are present and non-empty.
- Return a clarify string if missing: `"What time should I ...?"`
- Validate format (ISO 8601 for datetimes, HH:MM for times).
- Never pass unvalidated user input directly to AppleScript or shell.

### 6. Add fallback / simulation

If real integration is unavailable (API down, iOS permission missing):
- Return a realistic canned response.
- Tag simulated functions clearly in code with `# SIMULATED` comment.
- Add to `skills/demo-mode.md` simulated functions list.

### 7. Update MockMessageRouter (Swift)

In `FreeFall/FreeFall/Model/MessageRouting.swift`:
- Add keyword matching for the new intent.
- Return a realistic `IntentResult` with hardcoded demo params and response.

### 8. Add to function registry

Update `docs/function-registry.md`:
- Description, required params, optional params.
- Example user messages, example JSON output.
- Success response, clarification response, failure response.
- Real vs simulated status.

### 9. Test

```bash
# Test via HTTP endpoint
curl -X POST http://localhost:8000/message \
  -H "Content-Type: application/json" \
  -d '{"text": "<example user message>"}'
```

Verify:
- Correct intent returned by router.
- Action executes (or simulation runs).
- Reply is natural and helpful.
- Missing-param path returns clarification question.

### 10. Run lint

```bash
cd mac-backend && ruff check .
```

Fix all issues before marking done.

## Security Checklist

- [ ] No user input injected directly into AppleScript strings without escaping.
- [ ] No API keys hardcoded — loaded from environment.
- [ ] OAuth tokens (if any) never logged, never written to disk.
- [ ] Failure path returns safe string, not raw exception message to user.

## Definition of Done

- [ ] Intent in router system prompt with examples.
- [ ] Swift Intent enum updated.
- [ ] Python executor function written with type hints and error handling.
- [ ] Both `main.py` and `server.py` `_execute()` updated.
- [ ] MockMessageRouter handles new intent.
- [ ] `docs/function-registry.md` updated.
- [ ] Curl test passes.
- [ ] `ruff check .` passes.
