from tools.base import Tool


class CalendarEventTool(Tool):
    name = "create_calendar_event"
    description = "Add an event to the user's calendar. Use when user says 'add to calendar', 'schedule', 'book', or mentions a specific time block."
    schema = '{"title":"string","start":"YYYY-MM-DDTHH:MM:SS","end":"YYYY-MM-DDTHH:MM:SS"}'

    def execute(self, params: dict) -> tuple[str, list[dict]]:
        title = params.get("title", "Event")
        start = params.get("start", "")
        end = params.get("end", "")
        if not start or not end:
            return "What time does it start and end?", []
        reply = params.get("_response") or f"Added {title} to your calendar."
        return reply, [{"type": "create_calendar_event", "title": title, "start": start, "end": end}]
