from tools.base import Tool


class ReminderTool(Tool):
    name = "create_reminder"
    description = "Create a reminder at a specific time. Use when user says 'remind me', 'don't let me forget', 'ping me at', etc."
    schema = '{"title":"string","datetime":"YYYY-MM-DDTHH:MM:SS"}'

    def execute(self, params: dict) -> tuple[str, list[dict]]:
        title = params.get("title", "reminder")
        dt = params.get("datetime", "")
        if not dt:
            return "What time should I remind you?", []
        reply = params.get("_response") or f"Done. Reminding you: {title}."
        return reply, [{"type": "create_reminder", "title": title, "datetime": dt}]
