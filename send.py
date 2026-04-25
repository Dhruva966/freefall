"""
send.py — AppleScript iMessage sender.

Wraps osascript to send messages through Messages.app.
Phone numbers must be E.164 format (+1XXXXXXXXXX).
"""

import subprocess

# AppleScript template — placeholders filled by _build_script(), never via
# raw .format() on untrusted input.
_APPLESCRIPT = '''
tell application "Messages"
    set targetBuddy to "{phone}"
    set targetService to 1st service whose service type = iMessage
    set theBuddy to buddy targetBuddy of targetService
    send "{message}" to theBuddy
end tell
'''


class BuddyNotFoundError(Exception):
    """Raised when Messages.app can't find the recipient."""


def _escape(text: str) -> str:
    # AppleScript strings are delimited by double-quotes; escape them.
    return text.replace("\\", "\\\\").replace('"', '\\"')


def send_message(phone_number: str, message: str) -> None:
    """Send an iMessage to phone_number with the given message text.

    Raises BuddyNotFoundError if Messages.app cannot locate the recipient.
    Raises RuntimeError for any other osascript failure.
    """
    script = _APPLESCRIPT.format(
        phone=_escape(phone_number),
        message=_escape(message),
    )
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip()
        if "buddy" in stderr.lower() or "can't get buddy" in stderr.lower():
            raise BuddyNotFoundError(
                f"Messages.app could not find buddy '{phone_number}': {stderr}"
            )
        raise RuntimeError(f"osascript failed (exit {result.returncode}): {stderr}")


if __name__ == "__main__":
    # Swap in a real number before running.
    TEST_NUMBER = "+14088285844"
    TEST_MESSAGE = 'Hello from Free Fall! (test with "quotes")'
    print(f"Sending to {TEST_NUMBER}: {TEST_MESSAGE!r}")
    try:
        send_message(TEST_NUMBER, TEST_MESSAGE)
        print("Sent successfully.")
    except BuddyNotFoundError as e:
        print(f"Buddy not found: {e}")
    except RuntimeError as e:
        print(f"Send failed: {e}")
