"""
bot.py — main polling loop and entry point.

Polls chat.db every 1.5s for new incoming iMessages.
MVP trigger: message containing "apple pie" (case-insensitive) → reply "hello".
"""

import time

import db
import send

POLL_INTERVAL = 1.5  # seconds


def handle_message(sender: str, text: str) -> str:
    """Return the reply for a given message, or empty string to stay silent."""
    if "apple pie" in text.lower():
        return "hello"
    return ""


def run() -> None:
    """Start the polling loop. Runs until interrupted with Ctrl-C."""
    try:
        last_rowid = db.get_last_rowid()
    except Exception as exc:
        print(f"[fatal] Cannot open chat.db: {exc}")
        print("  → System Settings → Privacy & Security → Full Disk Access → add Terminal")
        return

    print(f"Free Fall started. Watching for new messages (cursor ROWID={last_rowid}).")
    print("Press Ctrl-C to stop.\n")

    while True:
        try:
            messages = db.get_recent_messages(last_rowid)
        except Exception as exc:
            print(f"[db error] {exc}")
            time.sleep(POLL_INTERVAL)
            continue

        for msg in messages:
            last_rowid = msg.rowid
            print(f"[{msg.sender}] {msg.text!r}")

            reply = handle_message(msg.sender, msg.text)
            if not reply:
                continue

            print(f"  → replying: {reply!r}")
            try:
                send.send_message(msg.sender, reply)
            except send.BuddyNotFoundError as exc:
                print(f"  [send error] {exc}")
            except RuntimeError as exc:
                print(f"  [send error] {exc}")

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    run()
