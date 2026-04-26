"""
Intent dispatcher. Called by message_monitor.py for each new inbound message.
"""

import gemma_router as router
import applescript_executor as ase
from tools import TOOL_MAP


def handle(sender: str, message: str) -> None:
    print(f"[main] routing: \"{message}\"")

    result = router.pre_route(message)
    intent = result.get("intent", "unknown")
    params = result.get("params", {})

    print(f"[main] intent={intent} params={params}")

    reply = _execute(intent, params, result.get("response", ""))
    print(f"[main] → \"{reply}\"")

    ase.send_imessage(sender, reply)


def _execute(intent: str, params: dict, model_response: str) -> str:
    if intent in ("answer", "clarify", "unknown"):
        return model_response or "Say more and I'll try again."

    tool = TOOL_MAP.get(intent)
    if tool is None:
        return model_response or "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\""

    params["_response"] = model_response
    reply, _ = tool.execute(params)
    return reply
