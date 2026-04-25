"""
Polls ~/Library/Messages/chat.db for new inbound messages addressed to the
Mac's iMessage handle (FREEFALL_HANDLE), then dispatches to main.handle().

REQUIREMENT: Terminal (or Python) needs Full Disk Access.
  System Settings → Privacy & Security → Full Disk Access → add Terminal / iTerm2
"""

import sqlite3
import time
import shutil
import tempfile
import os
from config import CHAT_DB, FREEFALL_HANDLE, POLL_INTERVAL, ALLOWED_SENDERS
import main as dispatcher

# Track the highest message rowid we've already processed
_last_rowid: int = 0


def _copy_db() -> str:
    # Messages.app holds a WAL lock on chat.db — copy to tmp before reading
    tmp = tempfile.mktemp(suffix=".db")
    shutil.copy2(CHAT_DB, tmp)
    return tmp


def _fetch_new_messages(tmp_db: str) -> list[dict]:
    conn = sqlite3.connect(tmp_db)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    # Direct join: message.handle_id → handle.rowid gives the actual per-message sender
    # Alias ROWID explicitly to avoid case mismatch when converting to dict
    cur.execute("""
        SELECT
            m.ROWID AS msg_rowid,
            m.text,
            m.is_from_me,
            h.id AS sender_handle,
            datetime(m.date / 1000000000 + 978307200, 'unixepoch', 'localtime') AS sent_at
        FROM message m
        LEFT JOIN handle h ON h.rowid = m.handle_id
        WHERE m.ROWID > ?
          AND m.is_from_me = 0
          AND m.text IS NOT NULL
          AND m.text != ''
        ORDER BY m.ROWID ASC
    """, (_last_rowid,))

    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows


def run() -> None:
    global _last_rowid

    print(f"[monitor] Watching chat.db — listening for messages to {FREEFALL_HANDLE}")
    print(f"[monitor] Poll interval: {POLL_INTERVAL}s  |  Ctrl-C to stop\n")

    # Seed last_rowid so we don't replay old messages on startup
    try:
        tmp = _copy_db()
        conn = sqlite3.connect(tmp)
        row = conn.execute("SELECT MAX(ROWID) FROM message").fetchone()
        _last_rowid = row[0] or 0
        conn.close()
        os.unlink(tmp)
        print(f"[monitor] Starting from rowid {_last_rowid}")
    except Exception as e:
        print(f"[monitor] WARNING: could not seed rowid — {e}")

    while True:
        try:
            tmp = _copy_db()
            messages = _fetch_new_messages(tmp)
            os.unlink(tmp)

            for msg in messages:
                _last_rowid = max(_last_rowid, msg["msg_rowid"])
                text = (msg["text"] or "").strip()
                if not text:
                    continue
                sender = msg.get("sender_handle")
                if not sender:
                    print(f"[monitor] skipping message rowid={msg['rowid']} — no sender_handle")
                    continue
                if sender == FREEFALL_HANDLE:
                    print("[monitor] skipping own-handle message")
                    continue
                if not ALLOWED_SENDERS:
                    print("[monitor] WARNING: ALLOWED_SENDERS not set — ignoring all messages (set it in .env)")
                    continue
                if sender not in ALLOWED_SENDERS:
                    print(f"[monitor] skipping {sender} — not in ALLOWED_SENDERS")
                    continue
                print(f"[monitor] ← \"{text}\" from {sender}")
                dispatcher.handle(sender=sender, message=text)

        except Exception as e:
            print(f"[monitor] Error reading chat.db: {e}")

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    run()
