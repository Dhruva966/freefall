import subprocess
from datetime import datetime


def _run(script: str) -> str:
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    return result.stdout.strip()


def send_imessage(handle: str, text: str) -> None:
    escaped = text.replace('"', '\\"')
    _run(f'''
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "{handle}" of targetService
            send "{escaped}" to targetBuddy
        end tell
    ''')


def create_reminder(title: str, iso_datetime: str) -> str:
    try:
        dt = datetime.fromisoformat(iso_datetime)
        mac_date = dt.strftime("%A, %B %d, %Y at %I:%M %p")
    except ValueError:
        return f"Couldn't parse the time for \"{title}\"."

    _run(f'''
        tell application "Reminders"
            tell list "Reminders"
                make new reminder with properties {{name:"{title}", due date:date "{mac_date}"}}
            end tell
        end tell
    ''')
    return f"Done. Reminding you to {title} at {dt.strftime('%-I:%M %p')}."


def create_calendar_event(title: str, start_iso: str, end_iso: str) -> str:
    try:
        start = datetime.fromisoformat(start_iso)
        end   = datetime.fromisoformat(end_iso)
        mac_start = start.strftime("%A, %B %d, %Y at %I:%M %p")
        mac_end   = end.strftime("%A, %B %d, %Y at %I:%M %p")
    except ValueError:
        return f"Couldn't parse the times for \"{title}\"."

    _run(f'''
        tell application "Calendar"
            tell calendar "Home"
                make new event with properties {{summary:"{title}", start date:date "{mac_start}", end date:date "{mac_end}"}}
            end tell
        end tell
    ''')
    return f"Added {title} {start.strftime('%-I:%M')}–{end.strftime('%-I:%M %p')}."


def set_alarm(time_hhmm: str) -> str:
    # macOS Clock.app has no AppleScript dictionary — best we can do is open Clock
    # and instruct user. For demo, create a reminder 1 min before as fallback.
    try:
        h, m = time_hhmm.split(":")
        now = datetime.now()
        alarm_dt = now.replace(hour=int(h), minute=int(m), second=0, microsecond=0)
        mac_date = alarm_dt.strftime("%A, %B %d, %Y at %I:%M %p")
    except Exception:
        return "Couldn't parse the alarm time."

    _run(f'''
        tell application "Reminders"
            tell list "Reminders"
                make new reminder with properties {{name:"⏰ Alarm", due date:date "{mac_date}"}}
            end tell
        end tell
    ''')
    return f"Set an alarm reminder for {alarm_dt.strftime('%-I:%M %p')}. It'll ping you on all your Apple devices."
