from tools.weather import WeatherTool
from tools.reminder import ReminderTool
from tools.calendar_event import CalendarEventTool
from tools.alarm import AlarmTool
from tools.send_message import SendMessageTool
from tools.shortcut import ShortcutTool
from tools.gmail import GmailTool

ALL_TOOLS = [
    WeatherTool(),
    ReminderTool(),
    CalendarEventTool(),
    AlarmTool(),
    SendMessageTool(),
    ShortcutTool(),
    GmailTool(),
]

TOOL_MAP = {t.name: t for t in ALL_TOOLS}
