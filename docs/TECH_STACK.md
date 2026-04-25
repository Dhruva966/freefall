# Tech Stack

## iPhone App

| Layer | Technology | Notes |
|-------|-----------|-------|
| Language | Swift 5.9+ | Swift concurrency (async/await, Task, @MainActor) |
| UI framework | SwiftUI | iMessage-style chat view, iOS 17+ target |
| AI inference | Core ML (primary) | Gemma270M.mlpackage bundled in app |
| AI fallback | MLX-Swift | github.com/ml-explore/mlx-swift-examples |
| Calendar/Reminders | EventKit | EKReminder + EKEvent, iOS 17 full-access API |
| Alarms | Shortcuts URL scheme | `shortcuts://run-shortcut?name=SetAlarm&input=HH:MM` |
| Weather | OpenWeatherMap API | Free tier, HTTPS, `api.openweathermap.org/data/2.5/forecast` |
| HTTP client | URLSession | Built-in, no third-party networking library |
| JSON parsing | Codable / JSONDecoder | Standard Swift, no third-party |
| Config | Config.swift (constants) | OWM API key, any other constants |

## Model

| Property | Value |
|----------|-------|
| Model | Gemma 3 270M Instruct (`google/gemma-3-270m-it`) |
| Size | ~135MB at Q8 quantization |
| Conversion | `python -m transformers.exporters.coreml` (swift-transformers) |
| Runtime | Apple Neural Engine via Core ML |
| Inference speed | ~20-50 tok/s on iPhone 15+ |
| Fallback | Gemma 3 1B 4-bit via MLX-Swift (~800MB download on first launch) |

## Key Constraints

- **iOS 17+** required (for `requestFullAccessToEvents()` / `requestFullAccessToReminders()`)
- **iPhone 12+** recommended for acceptable inference speed
- **Same WiFi** required for direct Xcode install (or TestFlight with iOS dev account)
- **Internet** required for weather only; all other functions work offline
- **No third-party networking** — URLSession only keeps app review clean

## Dependencies (SPM)

```swift
// Package.swift — only add if using MLX-Swift fallback
.package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "1.0.0")
```

No other external dependencies for the hackathon MVP.
