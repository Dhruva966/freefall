"""
db.py — chat.db query helpers.

Reads ~/Library/Messages/chat.db (read-only). Uses a ROWID cursor so the
caller never reprocesses old messages.

Apple's iMessage epoch starts 2001-01-01 00:00:00 UTC — not the Unix epoch.
Convert with: unix_ts = apple_ts + 978307200

macOS 13+ iMessage note: the `text` column is NULL for iMessages; the body is
stored as an NSAttributedString binary plist in `attributedBody`. SMS still
uses `text`. _decode_attributed_body() handles both cases.
"""

import os
import plistlib
import sqlite3
from dataclasses import dataclass
from typing import List, Optional

APPLE_EPOCH_OFFSET = 978307200

DB_PATH = os.path.expanduser("~/Library/Messages/chat.db")


@dataclass
class Message:
    rowid: int
    text: str
    sender: str
    unix_timestamp: int


def _connect() -> sqlite3.Connection:
    # Plain path connect works with macOS WAL-mode chat.db; PRAGMA query_only
    # prevents accidental writes without requiring URI sandbox support.
    con = sqlite3.connect(DB_PATH, check_same_thread=False)
    con.execute("PRAGMA query_only = ON")
    return con


def _decode_attributed_body(blob: bytes) -> Optional[str]:
    """Extract plain text from NSAttributedString stored in attributedBody.

    macOS Messages uses TypedStream format (magic: 'streamtyped'), NOT a binary
    plist. Structure after the \x01\x94 NSString type tag:
        [2 bytes class version] \x2b <length byte> <utf-8 text>
    \x2b ('+') is the TypedStream UTF-8 string encoding marker.

    Binary plist (bplist00) path kept as fallback for any future format change.
    """
    if not blob:
        return None

    # --- Binary plist (bplist00) fallback ---
    if blob[:6] == b'bplist':
        try:
            plist = plistlib.loads(blob)
            objects = plist.get("$objects", [])
            for obj in objects:
                if isinstance(obj, dict) and "NSString" in obj:
                    uid = obj["NSString"]
                    idx = uid.data if hasattr(uid, "data") else int(uid)
                    if 0 <= idx < len(objects) and isinstance(objects[idx], str):
                        return objects[idx]
        except Exception:
            pass

    # --- TypedStream (primary path) ---
    # After \x01\x94, scan up to 16 bytes for \x2b then read <length><utf8>.
    try:
        i = blob.find(b"\x01\x94")
        if i != -1:
            for j in range(i + 2, min(i + 16, len(blob) - 1)):
                if blob[j] == 0x2B:  # '+' = UTF-8 marker
                    length = blob[j + 1]
                    if length and j + 2 + length <= len(blob):
                        return blob[j + 2 : j + 2 + length].decode("utf-8")
    except Exception:
        pass

    return None


def get_last_rowid() -> int:
    """Return the current maximum ROWID in the message table.

    Call once at startup so the bot only acts on messages that arrive after
    launch. Returns 0 if the table is empty.
    """
    con = _connect()
    try:
        cur = con.execute("SELECT MAX(ROWID) FROM message")
        row = cur.fetchone()
        return row[0] if row and row[0] is not None else 0
    finally:
        con.close()


def get_recent_messages(last_rowid: int) -> List[Message]:
    """Return incoming messages with ROWID > last_rowid, oldest first.

    Handles both SMS (text column) and iMessage (attributedBody column).
    Returns an empty list on a transient DB lock so the polling loop keeps
    ticking.
    """
    query = """
        SELECT
            m.ROWID,
            m.text,
            m.attributedBody,
            m.date,
            h.id AS sender
        FROM message m
        JOIN handle h ON m.handle_id = h.ROWID
        WHERE m.ROWID > :last_rowid
          AND m.is_from_me = 0
          AND (m.text IS NOT NULL OR m.attributedBody IS NOT NULL)
        ORDER BY m.ROWID ASC
    """
    try:
        con = _connect()
        try:
            cur = con.execute(query, {"last_rowid": last_rowid})
            rows = cur.fetchall()
        finally:
            con.close()
    except sqlite3.OperationalError as exc:
        print(f"[db] locked, skipping poll: {exc}")
        return []

    messages = []
    for rowid, text, attributed_body, apple_ts, sender in rows:
        body = text or _decode_attributed_body(attributed_body)
        if not body:
            continue
        unix_ts = (apple_ts or 0) + APPLE_EPOCH_OFFSET
        messages.append(Message(rowid=rowid, text=body, sender=sender, unix_timestamp=unix_ts))
    return messages
