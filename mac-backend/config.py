import os

from dotenv import load_dotenv

load_dotenv()

OWM_API_KEY = os.getenv("OWM_API_KEY", "")
OWM_BASE = "https://api.openweathermap.org/data/2.5"
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "gemma3:1b")
FREEFALL_HANDLE = os.getenv("FREEFALL_HANDLE", "")
POLL_INTERVAL = float(os.getenv("POLL_INTERVAL", "1.5"))
CHAT_DB = os.path.expanduser(os.getenv("CHAT_DB", "~/Library/Messages/chat.db"))

_raw_senders = os.getenv("ALLOWED_SENDERS", "")
ALLOWED_SENDERS: set[str] = {s.strip() for s in _raw_senders.split(",") if s.strip()}
