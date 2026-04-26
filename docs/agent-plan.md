# Agent Plan — Free Fall

How to use the agent setup in this repo to build Free Fall faster.

## What AGENTS.md Does

`AGENTS.md` (repo root) is the first file any AI agent reads before touching code.
It answers:
- What is this project?
- Where does new code go? (mac-backend vs FreeFall vs legacy root files)
- How do I build and run it?
- What are the security rules?
- What is the workflow checklist before finishing a task?

Every agent task starts with reading AGENTS.md. This prevents agents from
editing legacy files, hardcoding secrets, or skipping the lint step.

## What Each Skill Does

Skills are in `skills/`. Each skill gives an agent deep context for one workflow.

| Skill file | When to use |
|---|---|
| `build-chat-interface.md` | Editing ChatView, MessageBubble, TypingIndicator, or ChatViewModel in the iOS app |
| `build-intent-router.md` | Changing gemma_router.py, the intent JSON schema, or MockMessageRouter |
| `add-function-tool.md` | Adding any new intent/action to the system |
| `build-weather-function.md` | Changing weather_service.py or adding weather to iOS |
| `build-calendar-reminder-function.md` | Changing create_reminder, create_calendar_event, or set_alarm |
| `build-gmail-search-function.md` | Adding real Gmail OAuth or changing the simulated response |
| `security-and-env.md` | Fixing config.py, adding .env support, or touching any credentials |
| `demo-mode.md` | Preparing for a demo, adding simulated responses, or fixing demo failures |

## How Claude Code Chooses Skills

1. Read the user's task description.
2. Identify which part of the codebase is affected (router? UI? a specific function?).
3. Pick the skill(s) that match. Most tasks need 1-2 skills.
4. Read the skill file(s) before reading any source code.
5. Follow the Definition of Done checklist in the skill.

Example mappings:
- "Add a play music function" → `add-function-tool.md`
- "Weather is returning HTTP not HTTPS" → `build-weather-function.md` + `security-and-env.md`
- "Chat bubbles look wrong on iPhone SE" → `build-chat-interface.md`
- "API key got committed" → `security-and-env.md`
- "Demo is crashing on the UCLA email phrase" → `demo-mode.md`

## How to Add New Skills

1. Create `skills/<skill-name>.md`.
2. Include: purpose, relevant files, rules, code patterns, and definition of done.
3. Reference the new skill in this doc (table above).
4. If the skill replaces a workflow in an existing skill, update the old skill to
   point to the new one.

Keep skills focused. One skill per workflow. If a skill grows beyond ~150 lines,
split it.

## How This Setup Helps Ship Free Fall Faster

Without AGENTS.md + skills, an agent must:
- Guess the project structure from scratch.
- Discover the legacy root files vs active mac-backend split on its own.
- Risk committing secrets because config.py pattern wasn't explained.
- Not know about the AppleScript alarm limitation.
- Not know DEMO_MODE exists.

With this setup, an agent gets all of that context in < 5 minutes of file reads,
then spends the rest of the task writing code instead of exploring.

Each skill also carries the Definition of Done checklist, which prevents
half-finished implementations that pass the task description but miss lint,
tests, or security requirements.
