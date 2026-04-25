"""
llm.py — local Mistral model interface.

Sends message text + optional conversation context to the on-device LLM
(via ollama or llama.cpp — TBD) and returns the response string.
No network calls; runs entirely on-device.
"""

from typing import Optional


def get_response(text: str, context: Optional[str] = None) -> str:
    """Send text to the local LLM and return its reply."""
    pass
