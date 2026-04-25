# Function Specifications

Five functions. Scope frozen for hackathon.

---

## 1. Set Reminders

**Intent:** `create_reminder`
**iOS API:** EventKit — EKReminder
**Permission:** `NSRemindersUsageDescription`

**User examples:**
- "Remind me to do my AP Stats homework at 7"
- "Remind me tomorrow morning to bring my laptop"
- "Set a reminder for robotics meeting prep tonight"

**Params from model:**
```json
{ "title": "AP Stats homework", "datetime": "2026-04-25T19:00:00" }
```

**Swift implementation (EventKitService.swift — singleton):**
```swift
// Create ONE shared EKEventStore for the app lifetime
// Re-creating per-call causes memory issues and re-triggers auth dialogs
class EventKitService {
    static let shared = EventKitService()
    private let store = EKEventStore()
    private var remindersAuthorized = false
    private var calendarAuthorized = false

    func requestAccess() async {
        remindersAuthorized = (try? await store.requestFullAccessToReminders()) ?? false
        calendarAuthorized  = (try? await store.requestFullAccessToEvents()) ?? false
    }

    func createReminder(title: String, datetime: Date) throws {
        guard remindersAuthorized else { throw AppError.permissionDenied }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: datetime)
        reminder.addAlarm(EKAlarm(absoluteDate: datetime))
        try store.save(reminder, commit: true)
    }
}

// Call requestAccess() ONCE at app launch, before any message is sent:
// EventKitService.shared.requestAccess()  ← in FreeFallApp.swift onAppear
```
```

**Success:** "Done. I'll remind you to [title] at [time]."
**Error:** "Couldn't set the reminder — check Reminders access in Settings."
**Offline:** ✅ fully local

---

## 2. Check Weather

**Intent:** `get_weather`
**API:** OpenWeatherMap — `api.openweathermap.org/data/2.5/forecast`
**Permission:** `NSLocationWhenInUseUsageDescription`
**API key:** `Config.OWM_API_KEY` (Person 2 creates account, free tier)

**User examples:**
- "What's the weather tomorrow morning?"
- "Will it rain today?"
- "What should I wear today?"

**Params from model:**
```json
{ "when": "tomorrow" }
```

**Swift implementation:**
```swift
func getWeather(when: String) async throws -> String {
    let location = try await LocationManager.shared.currentLocation()
    let url = URL(string: "https://api.openweathermap.org/data/2.5/forecast?lat=\(location.lat)&lon=\(location.lon)&appid=\(Config.OWM_API_KEY)&units=imperial")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let forecast = try JSONDecoder().decode(OWMForecast.self, from: data)
    return forecast.summary(for: when)
}
```

**Location fallback:** if permission denied, ask user "What city are you in?" and
use `q=CityName` instead of lat/lon in the API call.

**Success:** "Tomorrow morning: 62°F, cloudy. Bring a layer."
**Error:** "Can't reach weather right now. Check your connection."
**Offline:** ❌ requires internet

---

## 3. Create Calendar Events

**Intent:** `create_calendar_event`
**iOS API:** EventKit — EKEvent
**Permission:** `NSCalendarsUsageDescription`

**User examples:**
- "Add robotics practice tomorrow from 4 to 6"
- "Schedule a meeting with Varun Friday at 3"
- "Put my math test on my calendar next Tuesday"

**Params from model:**
```json
{ "title": "robotics practice", "start": "2026-04-26T16:00:00", "end": "2026-04-26T18:00:00" }
```

**Swift implementation:**
```swift
func createEvent(title: String, start: Date, end: Date) async throws {
    let store = EKEventStore()
    try await store.requestFullAccessToEvents()
    
    let event = EKEvent(eventStore: store)
    event.title = title
    event.startDate = start
    event.endDate = end
    event.calendar = store.defaultCalendarForNewEvents
    
    try store.save(event, span: .thisEvent, commit: true)
}
```

**Success:** "Added [title] [date] [start]–[end]."
**Error:** "Couldn't add event — check Calendar access in Settings."
**Offline:** ✅ fully local

---

## 4. Set Alarms / Timers

**Intent:** `set_alarm`
**Path:** Shortcuts URL scheme (iOS restricts direct alarm creation)
**Pre-req:** User creates a "SetAlarm" Shortcut once (document in app onboarding)

**User examples:**
- "Set an alarm for 7 AM"
- "Wake me up in 30 minutes"
- "Set a timer for 15 minutes"

**Params from model:**
```json
{ "time": "07:00" }
```

**Swift implementation:**
```swift
func setAlarm(time: String) {
    let encoded = time.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? time
    let url = URL(string: "shortcuts://run-shortcut?name=SetAlarm&input=\(encoded)")!
    UIApplication.shared.open(url)
}
```

**Note:** User must tap "Run" once in the Shortcuts confirmation. This is an iOS
limitation — cannot be bypassed without jailbreak.

**Success:** "Opening alarm for [time] — tap Run to confirm."
**Fallback:** "I can set a reminder instead — want that?" (if Shortcuts unavailable)
**Offline:** ✅ fully local (after Shortcuts opens)

---

## 5. Search Gmail (Simulated in v1)

**Intent:** `search_gmail`
**v1 behavior:** Return a canned realistic-looking response
**v2:** Gmail OAuth2 + `gmail.googleapis.com/gmail/v1/users/me/messages`

**User examples:**
- "Find the email from UCLA about Fast Track"
- "Search Gmail for the robotics invoice"
- "Do I have any emails from Mr. Wilder this week?"

**Params from model:**
```json
{ "query": "UCLA Fast Track" }
```

**v1 implementation:**
```swift
func searchGmail(query: String) -> String {
    // Simulated for hackathon demo
    return "Found it. The \(query) email mentions a Zoom info session on May 3rd with a link in the body."
}
```

**v2 implementation (post-hackathon):**
1. Google Sign-In SDK
2. OAuth2 scope: `https://www.googleapis.com/auth/gmail.readonly`
3. API call with `q` parameter
4. Return snippet of top result

**Success (v1):** "Found it. The [query] email mentions [canned detail]."
**Offline:** N/A in v1 (simulated)

---

## Error Handling Summary

| Scenario | Response |
|----------|----------|
| Model returns malformed JSON | "I didn't catch that. Try: 'Remind me to...'" |
| Unknown intent | "I can set reminders, check weather, add calendar events, or set alarms." |
| EventKit permission denied | "Check [Reminders/Calendar] access in Settings > Free Fall." |
| Location permission denied | "What city are you in?" (fallback to city-name API call) |
| OpenWeatherMap error | "Can't reach weather right now. Check your connection." |
| Shortcuts not available | Fall back to reminder with same time |
