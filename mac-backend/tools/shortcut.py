from tools.base import Tool


class ShortcutTool(Tool):
    name = "run_shortcut"
    description = "Run a named Apple Shortcut on the user's device. Use when user asks for automations like 'bedtime routine', 'focus mode', 'close apps', etc."
    schema = '{"name":"shortcut name"}'

    def execute(self, params: dict) -> tuple[str, list[dict]]:
        name = params.get("name", "")
        if not name:
            return "Which Shortcut should I run?", []
        reply = params.get("_response") or f"Running {name}."
        return reply, [{"type": "run_shortcut", "name": name}]
