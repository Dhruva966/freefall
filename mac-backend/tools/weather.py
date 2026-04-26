from tools.base import Tool
import weather_service as wx


class WeatherTool(Tool):
    name = "get_weather"
    description = "Get current or forecasted weather. Use when user asks about weather, temperature, conditions, rain, etc."
    schema = '{"when":"today|tomorrow"}'

    def execute(self, params: dict) -> tuple[str, list[dict]]:
        when = params.get("when", "today")
        return wx.get_weather(when=when), []
