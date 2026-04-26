# Skill: build-gmail-search-function

Build or update the Gmail search function.

## Relevant Files

- `mac-backend/main.py` — `GMAIL_CANNED` constant, `search_gmail` branch
- `mac-backend/server.py` — same canned response
- `mac-backend/gemma_router.py` — `search_gmail` intent schema

## Current State (v1)

Gmail search is **fully simulated**. Both `main.py` and `server.py` return:
```python
GMAIL_CANNED = "Found it. The UCLA Fast Track email mentions a Zoom info session on May 3rd."
```

This is intentional for the hackathon MVP. The demo loop works end-to-end
without real Gmail access.

## Adding Real Gmail Search (v2)

### OAuth Setup

1. Create a Google Cloud project at console.cloud.google.com.
2. Enable Gmail API.
3. Create OAuth 2.0 credentials (Desktop app type for local Mac use).
4. Download `credentials.json` — **never commit this file**.
5. Add `credentials.json` to `.gitignore`.
6. First run triggers browser OAuth flow → saves `token.json` locally.
7. Add `token.json` to `.gitignore`.

Required scope: `https://www.googleapis.com/auth/gmail.readonly`

### Implementation Pattern

```python
# mac-backend/gmail_service.py
import os
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]

def _get_service():
    creds = None
    if os.path.exists("token.json"):
        creds = Credentials.from_authorized_user_file("token.json", SCOPES)
    if not creds or not creds.valid:
        flow = InstalledAppFlow.from_client_secrets_file("credentials.json", SCOPES)
        creds = flow.run_local_server(port=0)
        with open("token.json", "w") as f:
            f.write(creds.to_json())
    return build("gmail", "v1", credentials=creds)

def search_gmail(query: str) -> str:
    try:
        service = _get_service()
        results = service.users().messages().list(
            userId="me", q=query, maxResults=5
        ).execute()
        messages = results.get("messages", [])
        if not messages:
            return f"No emails found for: {query}"
        # Fetch first message snippet
        msg = service.users().messages().get(
            userId="me", messageId=messages[0]["id"], format="metadata",
            metadataHeaders=["From", "Subject", "Date"]
        ).execute()
        headers = {h["name"]: h["value"] for h in msg["payload"]["headers"]}
        return f"Found: \"{headers.get('Subject','(no subject)')}\" from {headers.get('From','')} on {headers.get('Date','')}."
    except Exception as e:
        return "Couldn't search Gmail right now. Try again in a moment."
```

### Security Rules

- Never log OAuth tokens or raw message content.
- Never print sender email addresses to console in production.
- Use `gmail.readonly` scope only — never request write permissions in MVP.
- Store `credentials.json` and `token.json` outside the repo, or in a
  gitignored directory.
- Use dev/test Gmail account by default. Do not connect to real user Gmail
  unless the user has explicitly configured their own credentials.

### Search Query Format

Gmail search operators supported:
- `from:sender@example.com`
- `subject:keyword`
- `after:2026/01/01`
- Free text: `"UCLA Fast Track"`

The router extracts a `query` string from user message. Pass it directly to
Gmail API `q` parameter.

### Simulated Response (demo mode)

Keep `GMAIL_CANNED` as fallback when:
- `DEMO_MODE=true` in environment.
- `credentials.json` not found.
- Gmail API returns error.

Use realistic canned responses keyed to common demo queries:
```python
DEMO_RESPONSES = {
    "ucla": "Found it. The UCLA Fast Track email mentions a Zoom info session on May 3rd.",
    "default": "Found 3 emails matching your search. Most recent: \"Meeting tomorrow\" from advisor@school.edu.",
}
```

### Return Format

Always return a single concise string (1-2 sentences max). No raw JSON, no email
body dumps. Summarize — don't paste full email content.

## Definition of Done

- [ ] Simulated path works and returns realistic demo string.
- [ ] Real OAuth path (v2): credentials never committed, tokens never logged.
- [ ] Search works for sender, subject, and free text queries.
- [ ] Graceful failure message on any API error.
- [ ] `ruff check .` passes.
