# Free Fall — Claude Context

## What This Is

iMessage-style AI assistant for iPhone. Users text a contact named "Free Fall" in plain
English. Gemma 3 270M runs on-device (Core ML), interprets the request, and executes
actions via EventKit, Shortcuts, and OpenWeatherMap.

**Phase:** Hackathon MVP (weekend build, 3-person team)
**Differentiator:** Local-first + private. Poke (competitor, $300M) uses cloud. We run on-device.

---

## Documentation — Read These Before Building Anything

Before writing any code or making integration decisions, fetch the relevant docs.
Do not rely on training knowledge — these APIs evolve.

| What | URL / Path | When to fetch |
|------|-----------|---------------|
| swift-transformers exportcoreml | https://github.com/huggingface/swift-transformers | Any Core ML conversion work |
| MLX-Swift (fallback model path) | https://github.com/ml-explore/mlx-swift-examples | If Core ML conversion fails |
| Core ML integration guide | https://developer.apple.com/documentation/coreml | Model loading, prediction API |
| EventKit framework | https://developer.apple.com/documentation/eventkit | Reminders, Calendar, permissions |
| OpenWeatherMap forecast API | https://openweathermap.org/api/one-call-3 | Weather params, response format |
| Gemma 3 270M on HuggingFace | https://huggingface.co/google/gemma-3-270m-it | Model ID, tokenizer, prompt format |

**Rules:**
- Any task touching Core ML → fetch swift-transformers docs first. Conversion APIs change frequently. `torch.jit.trace` does NOT work on Gemma 3 (dynamic shapes). Always use `exportcoreml`.
- Any task touching EventKit → read the permissions section. `requestFullAccessToEvents()` is iOS 17+ only. Older API is deprecated and behaves differently.
- Any task touching OpenWeatherMap → verify the response JSON schema. Field names and nesting differ between `/forecast` (5-day) and `/onecall` (hourly). Use HTTPS, not HTTP (ATS blocks HTTP).

---

## Key Decisions (Don't Revisit)

| Decision | Choice | Reason |
|----------|--------|--------|
| Interface | SwiftUI fake iMessage UI | True iMessage extension blocked by Apple |
| Model | Gemma 3 270M → Core ML (MLX-Swift fallback) | Smallest viable LLM, runs on-device |
| Actions | EventKit directly on iPhone | No Mac, no iCloud sync delay, instant |
| Alarms | Shortcuts URL scheme | iOS restricts direct alarm creation |
| Gmail | Simulated in v1 | OAuth2 setup is a half-day time bomb |
| Weather | OpenWeatherMap HTTPS free tier | Only function requiring internet |
| Threading | Task {} + @MainActor | Standard Swift concurrency, no GCD |
| EKEventStore | Singleton (EventKitService.shared) | Re-creating per-call causes memory issues |

---

## Document Structure

```
freefall/
├── CLAUDE.md           ← you are here (entry point for new chats)
└── docs/
    ├── PRODUCT.md      ← 2-min read: what/why/competitor/pitch
    ├── ARCHITECTURE.md ← system diagram, model integration, file structure
    ├── FUNCTIONS.md    ← 5 function specs (parameters, Swift code, error handling)
    ├── TECH_STACK.md   ← language/framework/dependency quick reference
    ├── TEAM.md         ← 3-person split, responsibilities, checkpoints
    └── DEMO.md         ← live demo script + pre-demo checklist
```

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) first for any technical work.
Read [docs/FUNCTIONS.md](docs/FUNCTIONS.md) for any function-specific work.

---

## Critical Blockers (Validate Before Saturday)

1. **Core ML conversion** — does `google/gemma-3-270m-it` convert via `exportcoreml`? (Person 2)
2. **JSON reliability** — does Gemma 270M return parseable JSON for all 5 intents? (prompt engineering)
3. **iOS dev account** — TestFlight vs direct Xcode install (same WiFi required for direct install)

---

## Skill Routing

When a request matches a skill, invoke it. A false positive is cheaper than a false negative.

- Product/idea questions → `/office-hours`
- Architecture, "does this make sense" → `/plan-eng-review`
- Bugs, "why is this broken" → `/investigate`
- Code review → `/review`
- Ready to ship → `/ship`
- Security → `/cso`
- Save context → `/context-save`
