# Architecture: Free Fall

## Two Valid Approaches — Pick One

### Approach A: Mac Backend + AppleScript (Fastest Demo Path)

AppleScript drives macOS apps on the Mac. iCloud syncs Calendar and Reminders to iPhone.
iPhone app is a pure chat UI — no EventKit, no Core ML, no permission prompts.

```
[iPhone SwiftUI Chat UI]
        │
        │ POST { "message": "remind me to study at 7" }
        │ (local WiFi — same network as Mac)
        ▼
[Mac: FastAPI server (Python)]
        │
        ├── Gemma 270M via Ollama
        │   → { "intent": "create_reminder", "params": {...} }
        │
        └── AppleScript executor
            ├── Reminders.app  ← syncs to iPhone via iCloud
            ├── Calendar.app   ← syncs to iPhone via iCloud
            ├── osascript alarm (Clock.app)
            └── Mail.app search (for Gmail-style demo)
        │
        ▼
[JSON response] → iPhone SwiftUI displays confirmation
```

**AppleScript examples:**

```applescript
-- Set a reminder
tell application "Reminders"
    tell list "Reminders"
        make new reminder with properties {name:"study", due date:date "Friday, April 25, 2026 at 7:00 PM"}
    end tell
end tell

-- Create calendar event
tell application "Calendar"
    tell calendar "Home"
        make new event with properties {summary:"robotics practice", start date:date "Saturday, April 26 at 4:00PM", end date:date "Saturday, April 26 at 6:00PM"}
    end tell
end tell

-- Search Mail
tell application "Mail"
    set results to (messages of mailbox "INBOX" whose subject contains "UCLA")
    get subject of first item of results
end tell
```

**Python executor (Mac backend):**
```python
import subprocess, json
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

def run_applescript(script: str) -> str:
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    return result.stdout.strip()

@app.post("/message")
async def handle_message(body: MessageBody):
    intent = query_gemma(body.message)  # returns parsed IntentResult
    
    if intent["intent"] == "create_reminder":
        run_applescript(f'''
            tell application "Reminders"
                tell list "Reminders"
                    make new reminder with properties {{name:"{intent["params"]["title"]}", due date:date "{intent["params"]["datetime"]}"}}
                end tell
            end tell
        ''')
        return {"response": intent["response"]}
    # ... other intents
```

**Why this is faster for hackathon:**
- No Core ML conversion (the current biggest risk)
- No iOS permission dialogs mid-demo
- AppleScript is 5 lines per action
- iCloud sync means iPhone shows the result automatically
- Demo on iPhone still looks the same to judges

**Limitation:** Requires Mac + same WiFi as iPhone. Mac must stay awake.

---

### Approach B: Fully On-Device Core ML (Most Impressive)

Everything runs on iPhone. Model bundled in app. No Mac needed after install.

```
[iPhone SwiftUI Chat UI]
        │
        ▼
[Gemma 270M via Core ML — bundled in .app]
        │
        ▼
[ActionExecutor.swift]
        ├── EventKit (Reminders + Calendar)
        ├── Shortcuts URL scheme (alarms)
        └── OpenWeatherMap API (weather)
```

**Core ML Conversion — Use Apple's swift-transformers (NOT coremltools torch.jit.trace):**

`torch.jit.trace` fails on Gemma 3 — dynamic sequence lengths break static shape tracing.
`exportcoreml` from swift-transformers handles Gemma 3 correctly.

Run on Mac **this week**, not Saturday morning:

```bash
pip install swift-transformers
python -m transformers.exporters.coreml \
  --model google/gemma-3-270m-it \
  --output Gemma270M.mlpackage
```

**Gate rule: if conversion fails after 1 hour — switch to MLX-Swift immediately.**

Or use MLX-Swift (confirmed working on iPhone, March 2026):

```swift
// Package: github.com/ml-explore/mlx-swift-examples
import MLX

let modelContainer = try await LLMModelFactory.shared.loadContainer(
    configuration: ModelConfiguration(id: "mlx-community/gemma-3-1b-it-4bit")
)
let result = try await modelContainer.perform { model in
    try await model.generate(prompt: fullPrompt, maxTokens: 200)
}
```

MLX-Swift pulls model from HuggingFace on first launch (~800MB). Runs on Apple Neural Engine.

**Threading — inference must NOT block main thread:**

```swift
// ChatView.swift — correct pattern
Button("Send") {
    Task {
        isThinking = true           // show typing indicator
        let result = await router.route(inputText)
        await MainActor.run {
            messages.append(result.response)
            isThinking = false
        }
    }
}

// MessageRouter.swift — dispatched off main thread
func route(_ message: String) async -> IntentResult {
    return await Task.detached(priority: .userInitiated) {
        // Core ML dispatches to Apple Neural Engine internally
        let raw = try await self.runInference(self.buildPrompt(message))
        return self.parseOutput(raw)
    }.value
}
```

**JSON Reliability — extract JSON from noisy model output:**

Gemma 270M may wrap JSON in markdown or add preamble text. Extract before decode:

```swift
func parseOutput(_ raw: String) -> IntentResult {
    // Extract first {...} block from raw output
    guard let start = raw.firstIndex(of: "{"),
          let end = raw.lastIndex(of: "}") else {
        return .unknown
    }
    let jsonString = String(raw[start...end])

    guard let data = jsonString.data(using: .utf8),
          let result = try? JSONDecoder().decode(IntentResult.self, from: data) else {
        return .unknown
    }
    return result
}
```

**Retry on parse failure:**

```swift
func route(_ message: String, attempt: Int = 0) async -> IntentResult {
    let prompt = attempt == 0
        ? buildPrompt(message)
        : buildPrompt("IMPORTANT: output valid JSON only.\n" + message)

    let raw = await runInference(prompt)
    let result = parseOutput(raw)

    if result.intent == "unknown" && attempt < 1 {
        return await route(message, attempt: 1)
    }
    return result
}
```

**EventKit Authorization (must be async):**

```swift
// CORRECT — async
func requestEventAccess() async throws {
    let store = EKEventStore()
    let granted = try await store.requestFullAccessToEvents()
    guard granted else { throw AppError.calendarAccessDenied }
}

// WRONG — will hang silently on first call
// EKEventStore().save(event, span: .thisEvent, commit: true)
// Always request access FIRST, before any save call
```

---

## FINAL CHOICE: Approach B (On-Device)

User decision: run Gemma 270M on-device, EventKit for actions, no Mac backend.
Approach A is documented for reference only.

For the hackathon demo, Approach A removes the three biggest risks:
1. Core ML conversion failure
2. Gemma JSON reliability
3. iOS permission dialogs during demo

After the demo, swap in Core ML / MLX-Swift for on-device version.

---

## System Prompt

```
You are an iPhone assistant. Parse the user message and return JSON only. No prose.

Current date/time: {ISO8601_INJECTED_BY_CLIENT}
User location: {CITY_INJECTED_BY_CLIENT}

Intents: create_reminder, get_weather, create_calendar_event, set_alarm, search_gmail

Output format:
{"intent":"<intent>","params":{...},"response":"<natural language confirmation>"}

Param schemas:
- create_reminder:       {title:string, datetime:ISO8601}
- get_weather:           {when:"today"|"tomorrow"|ISO8601_date}
- create_calendar_event: {title:string, start:ISO8601, end:ISO8601}
- set_alarm:             {time:"HH:MM"}
- search_gmail:          {query:string}

Unknown/unclear: {"intent":"clarify","params":{},"response":"<ask user to clarify>"}
```

## Project File Structure

### Approach A (Mac + AppleScript)

```
FreeFall/
├── ios-app/                    ← SwiftUI iPhone app (chat UI only)
│   ├── FreeFall.xcodeproj
│   └── FreeFall/
│       ├── ChatView.swift
│       ├── MessageBubble.swift
│       ├── TypingIndicator.swift
│       ├── MessageService.swift     ← URLSession → Mac backend
│       └── Config.swift             ← MAC_URL, OWM_KEY
│
└── mac-backend/                ← Python FastAPI server
    ├── main.py                  ← FastAPI app
    ├── gemma_router.py          ← Ollama integration + prompt
    ├── applescript_executor.py  ← osascript wrappers
    ├── weather_service.py       ← OpenWeatherMap
    └── requirements.txt
```

### Approach B (On-Device)

```
FreeFall/
├── FreeFall.xcodeproj
└── FreeFall/
    ├── App/
    │   ├── FreeFallApp.swift
    │   └── Config.swift
    ├── Model/
    │   ├── Gemma270M.mlpackage      ← drag in after conversion
    │   ├── MessageRouter.swift      ← Core ML inference
    │   ├── ActionExecutor.swift
    │   └── IntentResult.swift
    ├── Views/
    │   ├── ChatView.swift
    │   ├── MessageBubble.swift
    │   └── TypingIndicator.swift
    ├── Services/
    │   ├── EventKitService.swift    ← async permission + save
    │   ├── WeatherService.swift
    │   ├── LocationManager.swift
    │   └── ShortcutsService.swift
    └── Info.plist
```
