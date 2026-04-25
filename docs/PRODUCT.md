# Product: Free Fall

## One-Line Pitch

"Like Poke, but your phone does the thinking."

## Problem

Users open separate apps for every small task — Reminders, Calendar, Clock, Weather,
Gmail. Free Fall collapses these into one interface they already know: texting.

## The Interface IS the Product

The iMessage aesthetic removes onboarding friction. Users don't learn a new tool.
They text a contact. The "whoa" moment: you type "remind me to study at 7" into what
looks like a normal text thread and your phone sets the reminder — no app switch, no
internet, no cloud.

## Competitive Context

**Poke** (direct competitor):
- Launched March 2026
- iMessage, SMS, Telegram, WhatsApp
- Features: calendar, email alerts, reminders, smart home, photo editing
- $25M funding, $300M valuation
- Architecture: cloud backend — your data goes to their servers

**Free Fall's wedge:**
- Local-first: Gemma 270M runs on your iPhone
- Private: no data leaves the device (except weather API call)
- No phone number required — no SMS costs

## Target User (Hackathon Demo)

A high schooler or college student who wants to automate small daily tasks without
installing a complex app or paying for a subscription. Technically curious but not a
developer.

Example persona: "I text my friends all day. I should be able to text my phone."

## MVP Scope (Frozen)

5 functions only. No scope creep:

1. Set reminders (natural language time parsing)
2. Check weather (location-aware, OpenWeatherMap)
3. Create calendar events (natural language date/time)
4. Set alarms/timers (Shortcuts bridge)
5. Search Gmail (simulated in v1)

## Success for the Demo

A judge sees a student text "remind me to submit my physics lab tonight at 8" and the
phone sets a real reminder — no app switch, no command syntax, no cloud required.
That's the whole game.

## V2 Vision

After hackathon: real Gmail OAuth, more functions (notes, Spotify, HomeKit), on-device
learning, widget for quick access, share via TestFlight.
