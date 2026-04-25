from fastapi import FastAPI
from pydantic import BaseModel
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
    sender: str = "demo"  # optional — used to send reply via AppleScript if needed


class MessageResponse(BaseModel):
    reply: str


@app.post("/message", response_model=MessageResponse)
async def handle_message(body: MessageRequest):
    result = router.route(body.text)
    intent = result.get("intent", "unknown")
    params = result.get("params", {})
    model_response = result.get("response", "")

    reply = _execute(intent, params, model_response)
    return MessageResponse(reply=reply)


def _execute(intent: str, params: dict, model_response: str) -> str:
    if intent == "create_reminder":
        title = params.get("title", "reminder")
        dt = params.get("datetime", "")
        if not dt:
            return "What time should I remind you?"
        return ase.create_reminder(title, dt)

    if intent == "get_weather":
        when = params.get("when", "today")
        return wx.get_weather(when=when)

    if intent == "create_calendar_event":
        title = params.get("title", "Event")
        start = params.get("start", "")
        end = params.get("end", "")
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

    return model_response or "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\""


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
