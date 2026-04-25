"""
debug.py — run this to diagnose the polling pipeline before starting bot.py.

Usage:
    python3 debug.py          # show last 10 raw rows from chat.db (no filters)
    python3 debug.py watch    # live-poll every 1.5s and print new messages
"""

import os
import plistlib
import sqlite3
import sys
import time

DB_PATH = os.path.expanduser("~/Library/Messages/chat.db")
APPLE_EPOCH_OFFSET = 978307200


def connect():
    con = sqlite3.connect(DB_PATH, check_same_thread=False)
    con.execute("PRAGMA query_only = ON")
    return con


def decode_attributed_body(blob):
    if not blob:
        return None
    try:
        plist = plistlib.loads(blob)
        objects = plist.get("$objects", [])
        for obj in objects:
            if isinstance(obj, dict) and "NSString" in obj:
                uid = obj["NSString"]
                idx = uid if isinstance(uid, int) else uid.data
                if 0 <= idx < len(objects) and isinstance(objects[idx], str):
                    return objects[idx]
    except Exception as e:
        return f"[decode error: {e}]"
    return None


# ── check DB is accessible ────────────────────────────────────────────────────
print(f"DB path : {DB_PATH}")
print(f"Exists  : {os.path.exists(DB_PATH)}")
try:
    con = connect()
    max_rowid = con.execute("SELECT MAX(ROWID) FROM message").fetchone()[0] or 0
    print(f"Max ROWID: {max_rowid}\n")
except Exception as e:
    print(f"OPEN ERROR: {e}")
    print("Fix: System Settings → Privacy & Security → Full Disk Access → add Terminal")
    sys.exit(1)

# ── raw dump: last 10 rows, NO filters, LEFT JOIN so nothing is dropped ───────
print("Last 10 messages (unfiltered, newest at bottom):")
print("-" * 80)
rows = con.execute("""
    SELECT
        m.ROWID,
        m.is_from_me,
        m.handle_id,
        h.id          AS sender,
        m.text        IS NOT NULL AS has_text,
        m.attributedBody IS NOT NULL AS has_body,
        m.text,
        m.attributedBody
    FROM message m
    LEFT JOIN handle h ON m.handle_id = h.ROWID
    ORDER BY m.ROWID DESC
    LIMIT 10
""").fetchall()
con.close()

for rowid, is_from_me, handle_id, sender, has_text, has_body, text, attributed_body in reversed(rows):
    direction = "OUT" if is_from_me else "IN "
    body = text or decode_attributed_body(attributed_body) or ""
    source = "text" if text else ("attributedBody" if attributed_body else "NONE")
    preview = (body[:60]).replace("\n", " ")
    print(f"  ROWID {rowid:>8}  {direction}  handle_id={handle_id}  sender={sender}")
    print(f"           source={source:<16} text={preview!r}")
print("-" * 80)

if len(sys.argv) >= 2 and sys.argv[1] == "hexdump":
    # Show first 80 bytes of attributedBody for the most recent incoming iMessage
    con = connect()
    row = con.execute("""
        SELECT m.ROWID, m.attributedBody
        FROM message m
        WHERE m.is_from_me = 0 AND m.attributedBody IS NOT NULL AND m.text IS NULL
        ORDER BY m.ROWID DESC LIMIT 1
    """).fetchone()
    con.close()
    if row:
        rowid, blob = row
        print(f"\nROWID {rowid} — attributedBody first 80 bytes:")
        print(" ".join(f"{b:02x}" for b in blob[:80]))
        print()
        try:
            print("Decoded as latin-1:", blob[:80].decode('latin-1'))
        except Exception as e:
            print(f"latin-1 error: {e}")
    else:
        print("No incoming iMessage with attributedBody found.")
    sys.exit(0)

if len(sys.argv) < 2 or sys.argv[1] != "watch":
    print("\nRun 'python3 debug.py watch' to live-poll for new messages.")
    sys.exit(0)

# ── watch mode ────────────────────────────────────────────────────────────────
print(f"\nWatching for new messages (cursor={max_rowid}). Send a text now...")
print("Press Ctrl-C to stop.\n")

cursor = max_rowid
while True:
    try:
        con = connect()
        rows = con.execute("""
            SELECT
                m.ROWID,
                m.is_from_me,
                m.handle_id,
                h.id AS sender,
                m.text,
                m.attributedBody
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.ROWID > ?
            ORDER BY m.ROWID ASC
        """, (cursor,)).fetchall()
        con.close()

        for rowid, is_from_me, handle_id, sender, text, attributed_body in rows:
            cursor = rowid
            direction = "OUT" if is_from_me else "IN "
            body = text or decode_attributed_body(attributed_body) or ""
            source = "text" if text else ("attributedBody" if attributed_body else "NONE")
            print(f"[NEW {direction}] ROWID={rowid}  handle_id={handle_id}  sender={sender}")
            print(f"         source={source}  body={body[:80]!r}")
            if not is_from_me and "apple pie" in body.lower():
                print("         ✓ 'apple pie' matched!")
    except sqlite3.OperationalError as e:
        print(f"[db locked] {e}")

    time.sleep(1.5)
