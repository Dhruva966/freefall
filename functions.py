"""
functions.py — NLP → Apple Shortcuts mapping layer.

Matches raw user text to a predefined function (set reminder, add calendar
event, etc.) and triggers the corresponding Shortcut via `shortcuts run`.
Returns None if no function matches so bot.py falls through to the LLM.
"""

import subprocess
from typing import Optional


SHORTCUTS = {
    "SetReminder": ["remind", "reminder"],
    "AddCalendarEvent": ["calendar", "schedule", "event"],
    "SetAlarm": ["alarm", "wake me"],
}


def match_and_run(text: str) -> Optional[str]:
    """Try to match text to a known function and run its Shortcut.

    Returns a confirmation string on success, None if no match.
    """
    pass


def run_shortcut(name: str, input_text: Optional[str] = None) -> None:
    """Execute a named Apple Shortcut, optionally passing input."""
    pass
