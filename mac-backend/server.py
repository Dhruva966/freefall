from fastapi import FastAPI
from pydantic import BaseModel
from typing import Any
import gemma_router as router
import applescript_executor as ase
import weather_service as wx

app = FastAPI()

from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST"],
    allow_headers=["Content-Type"],
)

GMAIL_CANNED = "Found it. The UCLA Fast Track email mentions a Zoom info session on May 3rd."


class MessageRequest(BaseModel):
    text: str
    sender: str = "demo"


class MessageResponse(BaseModel):
    reply: str
    actions: list[dict[str, Any]] = []


@app.post("/message", response_model=MessageResponse)
async def handle_message(body: MessageRequest):
    result = router.pre_route(body.text)
    intent = result.get("intent", "unknown")
    params = result.get("params", {})
    model_response = result.get("response", "")

    reply, actions = _execute(intent, params, model_response)
    return MessageResponse(reply=reply, actions=actions)


def _execute(intent: str, params: dict, model_response: str) -> tuple[str, list[dict]]:
    # Conversational — no action
    if intent in ("answer", "clarify", "unknown"):
        return model_response or "Say more and I'll try again.", []

    # Mac-side: send iMessage via AppleScript
    if intent == "send_message":
        to = params.get("to", "")
        msg = params.get("message", "")
        if not to or not msg:
            return "Who should I text, and what should I say?", []
        return ase.send_message_to_contact(to, msg), []

    # Mac-side: weather API
    if intent == "get_weather":
        when = params.get("when", "today")
        return wx.get_weather(when=when), []

    # Mac-side: Gmail (canned for now)
    if intent == "search_gmail":
        return GMAIL_CANNED, []

    # Device-side: iOS executes via EventKit
    if intent == "create_reminder":
        title = params.get("title", "reminder")
        dt = params.get("datetime", "")
        if not dt:
            return "What time should I remind you?", []
        reply = model_response or f"Done. Reminding you: {title}."
        return reply, [{"type": "create_reminder", "title": title, "datetime": dt}]

    if intent == "create_calendar_event":
        title = params.get("title", "Event")
        start = params.get("start", "")
        end = params.get("end", "")
        if not start or not end:
            return "What time does it start and end?", []
        reply = model_response or f"Added {title} to your calendar."
        return reply, [{"type": "create_calendar_event", "title": title, "start": start, "end": end}]

    # Device-side: iOS executes via Shortcuts (real Clock alarm)
    if intent == "set_alarm":
        t = params.get("time", "")
        if not t:
            return "What time should I set the alarm for?", []
        label = params.get("label", "Alarm")
        reply = model_response or f"Alarm set for {t}."
        return reply, [{"type": "set_alarm", "time": t, "label": label}]

    if intent == "set_alarms":
        times = params.get("times", [])
        label = params.get("label", "Study")
        if not times:
            return "What times should I set alarms for?", []
        actions = [{"type": "set_alarm", "time": t, "label": label} for t in times]
        reply = model_response or f"Set {len(times)} alarms."
        return reply, actions

    # Device-side: arbitrary Shortcut by name
    if intent == "run_shortcut":
        name = params.get("name", "")
        if not name:
            return "Which Shortcut should I run?", []
        return model_response or f"Running {name}.", [{"type": "run_shortcut", "name": name}]

    return model_response or "I didn't catch that.", []


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
