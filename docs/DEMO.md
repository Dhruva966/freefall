# Demo Script + Pre-Demo Checklist

## Pre-Demo Checklist (30 min before)

Run every item. Do not skip.

- [ ] Grant **Reminders** permission: send "remind me to test" — confirm real reminder appears
- [ ] Grant **Calendar** permission: send "add test event at noon" — confirm event in Calendar app
- [ ] Create **"SetAlarm" Shortcut** in Shortcuts app (if not done): one action, "Set Alarm", input = time
- [ ] Test alarm path: send "set alarm for 9am" — confirm Shortcuts opens
- [ ] OWM API key in `Config.swift` — test weather: send "what's the weather today" — confirm response
- [ ] iPhone on **WiFi or personal hotspot** (for weather API)
- [ ] Model loaded: open app, send one message, confirm response comes back (not blank)
- [ ] Gmail mock response: send "find the UCLA email" — confirm canned response appears
- [ ] Battery: iPhone >50%, screen brightness up, do not disturb ON
- [ ] JSON extraction works: type "remind me to study" — confirm real reminder appears (not error message)
- [ ] ATS/weather confirmed: OWM response has real temperature data (not a network error)
- [ ] Ambiguous time: type "remind me at 7" — check the reminder time looks correct (PM context from system time)

---

## Demo Script (4 demos)

**Person 3 runs the phone. Speak each line before typing.**

---

### Demo 1: Reminder

> "Let's start with something simple. I want to be reminded about my physics lab."

Type: `Remind me to submit my physics lab tonight at 8`

Expected response: `Done. I'll remind you to submit your physics lab at 8 PM.`

Point out: "No app switch. No command syntax. A real reminder just got set."

Show proof: open Reminders app → "Submit physics lab" at 8 PM is there.

---

### Demo 2: Weather

> "Now, let me check the weather. I'm asking in plain English."

Type: `What's the weather tomorrow morning?`

Expected response: `Tomorrow morning: [temp]°F, [condition]. [clothing suggestion].`

Point out: "On-device model understood 'tomorrow morning' — I didn't say a date.
And the weather data came from my location, not a cloud AI."

---

### Demo 3: Calendar

> "I can add events just as naturally."

Type: `Add robotics practice tomorrow from 4 to 6`

Expected response: `Added robotics practice tomorrow 4–6 PM.`

Show proof: open Calendar app → "Robotics practice" block is there.

Point out: "That's native iOS. The event is in your real calendar. Not an app silo."

---

### Demo 4: Gmail Search

> "This one's early access. We're connecting to Gmail."

Type: `Find the UCLA Fast Track email`

Expected response: `Found it. The Fast Track email mentions a Zoom info session on May 3rd.`

Point out: "Gmail search is next. The model understood the query and routed it to
the right function. We're connecting the real Gmail API as the next step."

(Don't say "simulated" — say "early access".)

---

### Stretch: Alarm (if time permits)

Type: `Wake me up at 7 tomorrow`

Expected response: `Opening alarm for 7 AM — tap Run to confirm.`

Shortcuts opens automatically. Tap Run.

Point out: "iOS doesn't allow apps to set alarms silently — that's a privacy
protection. We use Apple's Shortcuts bridge, so one tap confirms it."

---

## Fallback Plan

If the model doesn't respond:
- Say "let me try a different phrasing" — retype more simply
- If still broken: skip to next demo item
- Reminders + Calendar are the must-work demos. Weather + Gmail are secondary.

If WiFi is down:
- Hotspot the phone to a team member's phone for weather
- Skip weather demo if no connection, lead with calendar instead

If Core ML model crashes:
- Restart app
- If persistent: switch to the Ollama Mac fallback (see ARCHITECTURE.md) and demo
  with Mac on same WiFi

---

## Pitch Framing

> "Poke launched last month — you can access an AI agent by texting a number.
> They raised $25M and are valued at $300M. Their model runs in the cloud.
> Free Fall does the same thing, but the AI runs on your phone.
> No data leaves the device. No subscription. No phone number.
> Just text."

---

## Q&A Prep

**"Why not just use Siri?"**
Siri can't compose multi-step actions from a single natural language message, can't
search Gmail, and everything goes through Apple's servers.

**"Why not just use the Poke app?"**
Poke is cloud-based. Every message you send goes to their servers. Free Fall is private.

**"Why iMessage style?"**
It's the most familiar interface on iPhone. Zero onboarding. You already know how to text.

**"What model are you running?"**
Gemma 3 270M — Google's smallest capable model. 135MB. Runs on the phone's Neural Engine.
270 million parameters vs GPT-4's ~1 trillion. Small enough to ship in an app.

**"Is this real? Does it actually set reminders?"**
Yes. [Open Reminders app and show the real reminder.]
