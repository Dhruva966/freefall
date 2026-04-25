# Team Split

3-person team. Weekend hackathon. Every person has a vertical slice.

---

## Person 1: iPhone App + UI + Action Execution

**Owns:**
- SwiftUI chat view with iMessage aesthetic
  - Blue user bubbles (right-aligned), gray assistant bubbles (left-aligned)
  - "Free Fall" contact name + avatar at top (simulate a contact)
  - Typing indicator (animated dots while model runs)
  - Message history with scroll
  - Text input + send button
- EventKit integration
  - `EKReminder` for reminders
  - `EKEvent` for calendar events
  - Permission request flow (prompt before first use)
- OpenWeatherMap `URLSession` call
  - `OWMForecast` decoder
  - City fallback if location denied
- Shortcuts URL scheme for alarms
- `IntentResult` parsing and error handling (malformed JSON → fallback message)

**First task Saturday morning:**
Create a blank SwiftUI project, add a `ChatView` with static hardcoded messages
in the iMessage style. Make it look right before wiring anything up.

---

## Person 2: Gemma 270M + Model Integration

**Owns:**
- Core ML conversion (run on Mac before hackathon Saturday)
  - `pip install coremltools transformers torch`
  - Convert `google/gemma-3-270m-it` → `Gemma270M.mlpackage`
  - If conversion fails: switch to Gemma 4 E2B via MLX-Swift immediately (don't debug for >2 hours)
- Bundle `.mlpackage` in Xcode project
- `MessageRouter.swift` — builds prompt with injected date/time/city, calls Core ML
- Prompt engineering — validate all 5 intents return well-formed JSON before Saturday
- OpenWeatherMap account setup → share API key in team channel
- `Config.swift` — OWM key, any other constants

**Critical pre-work (do this week, not Saturday):**
Run the Core ML conversion. Then in a Python notebook, hit the model with 20
different phrasing variations of each intent and count how many return valid JSON.
If reliability is below 80%, add few-shot examples to the system prompt until it is.

**If Core ML conversion fails (escalation path):**
1. Try `coremltools` nightly build
2. Switch to Gemma 4 E2B via `mlx-swift-examples` (see ARCHITECTURE.md fallback section)
3. Last resort: run Ollama on Mac, iPhone hits Mac over WiFi (Approach A fallback)

---

## Person 3: UX Polish + Integration + Demo

**Owns:**
- Connecting all pieces end-to-end (Person 1 UI + Person 2 model → full flow)
- Typography, spacing, animations — make it feel native
  - Font: SF Pro (system default, no custom fonts)
  - Bubble corner radius: 18pt (match Messages)
  - Send button: system blue, SF Symbol `paperplane.fill`
- Pre-demo checklist execution (see DEMO.md)
- Mock Gmail response copy — make it sound realistic
- Demo script and rehearsal (run through 4 demos 3x before presenting)
- WiFi/hotspot setup for weather API calls at venue

**Day of demo:**
Person 3 runs the phone during the demo. Person 1 and 2 stand by for instant debugging.
If anything breaks mid-demo, fall back to the next demo item and circle back.

---

## Integration Checkpoints

| Time | Checkpoint |
|------|------------|
| Friday night | Person 1: SwiftUI chat UI with static messages looks like iMessages |
| Friday night | Person 2: Core ML conversion complete, model returns JSON in Python |
| Saturday noon | Person 1 + 2: MessageRouter calls Core ML, response appears in chat |
| Saturday 3pm | All 5 demo flows work end-to-end (actions simulated OK if needed) |
| Saturday 6pm | Full dry run of demo script — 3x through |
| Demo day | Pre-demo checklist complete 30 min before |
