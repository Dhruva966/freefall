from fastapi import FastAPI
from pydantic import BaseModel
from typing import Any
import gemma_router as router
from tools import TOOL_MAP

app = FastAPI()

from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST"],
    allow_headers=["Content-Type"],
)

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
    if intent in ("answer", "clarify", "unknown"):
        return model_response or "Say more and I'll try again.", []

    tool = TOOL_MAP.get(intent)
    if tool is None:
        return model_response or "I didn't catch that.", []

    params["_response"] = model_response
    return tool.execute(params)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
