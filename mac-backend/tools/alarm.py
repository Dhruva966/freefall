from tools.base import Tool


class AlarmTool(Tool):
    name = "set_alarm"
    description = "Set one or more alarms on the user's phone. Use when user says 'set an alarm', 'wake me up', 'alarm at X'."
    schema = '{"times":["HH:MM"],"label":"optional label"}'

    def execute(self, params: dict) -> tuple[str, list[dict]]:
        times = params.get("times") or ([params["time"]] if params.get("time") else [])
        label = params.get("label", "Alarm")
        if not times:
            return "What time should I set the alarm for?", []
        actions = [{"type": "set_alarm", "time": t, "label": label} for t in times]
        reply = params.get("_response") or f"Set {len(times)} alarm{'s' if len(times) > 1 else ''}."
        return reply, actions
