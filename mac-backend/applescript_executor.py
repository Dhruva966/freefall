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


def lookup_contact(name: str) -> str | None:
    """Returns phone or email for a contact by first name, or None if not found."""
    escaped = name.replace('"', '\\"')
    script = f'''
        tell application "Contacts"
            set matches to (every person whose name contains "{escaped}")
            if (count of matches) = 0 then return ""
            set p to item 1 of matches
            if (count of phones of p) > 0 then
                return value of item 1 of phones of p
            else if (count of emails of p) > 0 then
                return value of item 1 of emails of p
            end if
            return ""
        end tell
    '''
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    val = result.stdout.strip()
    return val if val else None


def send_message_to_contact(name: str, message: str) -> str:
    handle = lookup_contact(name)
    if not handle:
        return f"Couldn't find {name} in your contacts."
    escaped_msg = message.replace('"', '\\"')
    _run(f'''
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "{handle}" of targetService
            send "{escaped_msg}" to targetBuddy
        end tell
    ''')
    return f"Sent to {name}: \"{message}\""


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


def set_alarm(time_hhmm: str, label: str = "⏰ Alarm") -> str:
    try:
        h, m = time_hhmm.split(":")
        now = datetime.now()
        alarm_dt = now.replace(hour=int(h), minute=int(m), second=0, microsecond=0)
        mac_date = alarm_dt.strftime("%A, %B %d, %Y at %I:%M %p")
        escaped_label = label.replace('"', '\\"')
    except Exception:
        return "Couldn't parse the alarm time."

    _run(f'''
        tell application "Reminders"
            tell list "Reminders"
                make new reminder with properties {{name:"{escaped_label}", due date:date "{mac_date}"}}
            end tell
        end tell
    ''')
    return alarm_dt.strftime("%-I:%M %p")


def set_alarms(times: list[str], label: str = "Study") -> str:
    results = []
    for t in times:
        result = set_alarm(t, label=f"⏰ {label}")
        results.append(result)
    if not results:
        return "No valid times found."
    joined = ", ".join(results)
    return f"Set {len(results)} alarms: {joined}. They'll ping you on all your Apple devices."
