"""
Intent dispatcher. Called by message_monitor.py for each new inbound message.
"""

import gemma_router as router
import applescript_executor as ase
import weather_service as wx
from config import FREEFALL_HANDLE

# Gmail is simulated in v1
GMAIL_CANNED = "Found it. The UCLA Fast Track email mentions a Zoom info session on May 3rd."


def handle(sender: str, message: str) -> None:
    print(f"[main] routing: \"{message}\"")

    result = router.route(message)
    intent = result.get("intent", "unknown")
    params = result.get("params", {})

    print(f"[main] intent={intent} params={params}")

    reply = _execute(intent, params, result.get("response", ""))
    print(f"[main] → \"{reply}\"")

    ase.send_imessage(sender, reply)


def _execute(intent: str, params: dict, model_response: str) -> str:
    if intent == "create_reminder":
        title = params.get("title", "reminder")
        dt    = params.get("datetime", "")
        if not dt:
            return "What time should I remind you?"
        return ase.create_reminder(title, dt)

    if intent == "get_weather":
        when = params.get("when", "today")
        # City injected from config — could be user's location in v2
        return wx.get_weather(when=when)

    if intent == "create_calendar_event":
        title = params.get("title", "Event")
        start = params.get("start", "")
        end   = params.get("end", "")
        if not start or not end:
            return "What time does it start and end?"
        return ase.create_calendar_event(title, start, end)

    if intent == "set_alarm":
        t = params.get("time", "")
        if not t:
            return "What time should I set the alarm for?"
        return ase.set_alarm(t)

    if intent == "search_gmail":
        return GMAIL_CANNED

    if intent == "clarify":
        return model_response or "Can you say that differently?"

    # unknown / fallback
    return model_response or "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\""
