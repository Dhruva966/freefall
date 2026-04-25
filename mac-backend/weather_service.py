import requests
from config import OWM_API_KEY, OWM_BASE


def get_weather(when: str = "today", city: str = "San Francisco") -> str:
    if not OWM_API_KEY:
        return "Weather not set up — OWM_API_KEY missing from .env."

    try:
        resp = requests.get(
            f"{OWM_BASE}/forecast",
            params={"q": city, "appid": OWM_API_KEY, "units": "imperial", "cnt": 16},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        return f"Can't reach weather right now. ({e})"

    forecasts = data.get("list", [])
    if not forecasts:
        return "No weather data available."

    # Pick the most relevant forecast slot for "today" or "tomorrow"
    from datetime import datetime, timedelta
    now = datetime.now()
    target_date = now.date() if when == "today" else (now + timedelta(days=1)).date()

    slots = [
        f for f in forecasts
        if datetime.fromtimestamp(f["dt"]).date() == target_date
    ]
    slot = slots[0] if slots else forecasts[0]

    temp  = round(slot["main"]["temp"])
    feels = round(slot["main"]["feels_like"])
    desc  = slot["weather"][0]["description"].capitalize()
    dt    = datetime.fromtimestamp(slot["dt"])

    return f"{dt.strftime('%A')} {dt.strftime('%-I %p')}: {temp}°F (feels {feels}°F), {desc}."
