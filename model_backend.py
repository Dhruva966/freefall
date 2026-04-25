from transformers import AutoProcessor, AutoModelForCausalLM
import requests
import json, re
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from dotenv import load_dotenv
import os
import subprocess

load_dotenv()
temp_key = os.getenv("OPENWEATHERMAP_KEY")


# ── Load FunctionGemma ──────────────────────────────────────────────
processor = AutoProcessor.from_pretrained("google/functiongemma-270m-it", device_map="auto")
model = AutoModelForCausalLM.from_pretrained("google/functiongemma-270m-it", dtype="auto", device_map="auto")


# ── Tool 1: Weather ─────────────────────────────────────────────────
def get_current_weather(location: str, unit: str = "fahrenheit"):
    """
    Gets the current weather for a given location.

    Args:
        location: City name. e.g. "San Francisco"
        unit: Temperature unit. (choices: ["celsius", "fahrenheit"])
    Returns:
        temperature: Current temperature
        weather: Weather description
        location: The location queried
    """
    API_KEY = temp_key
    units = "imperial" if unit == "fahrenheit" else "metric"
    url = f"https://api.openweathermap.org/data/2.5/weather?q={location}&appid={API_KEY}&units={units}"

    resp = requests.get(url)
    data = resp.json()

    if data.get("cod") != 200:
        return {"error": f"Could not find weather for '{location}': {data.get('message', 'unknown error')}"}

    return {
        "location": location,
        "temperature": data["main"]["temp"],
        "weather": data["weather"][0]["description"],
        "unit": unit
    }


# ── Tool 2: Calendar (AppleScript) ───────────────────────────────────
def create_calendar_event(
    title: str,
    start_datetime: str,
    end_datetime: str = "",
    location: str = "",
    notes: str = ""
):
    """
    Creates a calendar event on macOS using AppleScript.

    Args:
        title: Title of the event. e.g. "Lunch with Sarah"
        start_datetime: ISO 8601 start. e.g. "2026-04-26T13:00:00"
        end_datetime: ISO 8601 end. e.g. "2026-04-26T14:00:00". Defaults to 1 hour after start if not provided.
        location: Optional location. e.g. "San Mateo, CA"
        notes: Optional notes. e.g. "Remember to bring flowers"
    Returns:
        status: "success" or "error"
        message: Result details
    """
    if not end_datetime:
        start = datetime.strptime(start_datetime, "%Y-%m-%dT%H:%M:%S")
        end_datetime = (start + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%S")

    start_dt = datetime.strptime(start_datetime, "%Y-%m-%dT%H:%M:%S")
    end_dt = datetime.strptime(end_datetime, "%Y-%m-%dT%H:%M:%S")

    as_start = start_dt.strftime("%B %-d, %Y at %-I:%M:%S %p")
    as_end   = end_dt.strftime("%B %-d, %Y at %-I:%M:%S %p")

    print(f"[Start]: {as_start}")
    print(f"[End]:   {as_end}")

    script = f"""
    tell application "Calendar"
        tell calendar "Calendar"
            set newEvent to make new event with properties {{summary:"{title}", start date:date "{as_start}", end date:date "{as_end}"}}
            set time zone of newEvent to "America/Los_Angeles"
            {f'set location of newEvent to "{location}"' if location else ''}
            {f'set description of newEvent to "{notes}"' if notes else ''}
        end tell
        reload calendars
    end tell
    """

    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    print(f"[AppleScript stdout]: {result.stdout}")
    print(f"[AppleScript stderr]: {result.stderr}")

    if result.returncode == 0:
        return {"status": "success", "message": f"'{title}' added to calendar"}
    else:
        return {"status": "error", "message": result.stderr}


# ── FunctionGemma inference ──────────────────────────────────────────
TOOLS = [get_current_weather, create_calendar_event]
TOOL_MAP = {
    "get_current_weather": get_current_weather,
    "create_calendar_event": create_calendar_event,
}


def run(user_message: str):
    now = datetime.now(ZoneInfo("America/Los_Angeles")).strftime("%Y-%m-%dT%H:%M:%S")
    print(f"[Current datetime]: {now}")

    messages = [
        {
            "role": "developer",
            "content": (
                f"You are a function calling assistant. "
                f"When the user asks about weather, you MUST call get_current_weather. "
                f"When the user asks to create a calendar event, you MUST call create_calendar_event. "
                f"Always call a function. Never decline. Never explain. Just call the function. "
                f"Current date and time: {now}."
            )
        },
        # ── Few-shot example 1: weather ──
        {"role": "user", "content": "What's the weather in Tokyo?"},
        {"role": "assistant", "content": "<start_function_call>call:get_current_weather{location:<escape>Tokyo<escape>,unit:<escape>fahrenheit<escape>}<end_function_call>"},
        # ── Few-shot example 2: calendar ──
        {"role": "user", "content": "Book a meeting tomorrow at 2pm called Team Sync"},
        {"role": "assistant", "content": "<start_function_call>call:create_calendar_event{title:<escape>Team Sync<escape>,start_datetime:<escape>2026-04-26T14:00:00<escape>}<end_function_call>"},
        # ── Actual user message ──
        {"role": "user", "content": user_message}
    ]

    inputs = processor.apply_chat_template(
        messages,
        tools=TOOLS,
        add_generation_prompt=True,
        return_dict=True,
        return_tensors="pt"
    )

    out = model.generate(
        **inputs.to(model.device),
        pad_token_id=processor.eos_token_id,
        max_new_tokens=256
    )

    raw = processor.decode(out[0][len(inputs["input_ids"][0]):], skip_special_tokens=True)

    fn_name, fn_result = dispatch(raw)

    if fn_name is None:
        print(fn_result)
        return

    messages.append({"role": "assistant", "content": raw})
    messages.append({"role": "tool", "name": fn_name, "content": json.dumps(fn_result)})

    inputs2 = processor.apply_chat_template(
        messages,
        tools=TOOLS,
        add_generation_prompt=True,
        return_dict=True,
        return_tensors="pt"
    )

    out2 = model.generate(
        **inputs2.to(model.device),
        pad_token_id=processor.eos_token_id,
        max_new_tokens=256
    )

    final = processor.decode(out2[0][len(inputs2["input_ids"][0]):], skip_special_tokens=True)
    print(f"\n{final}\n")


def dispatch(raw: str):
    """Parse model output and call the right function. Returns (fn_name, result)."""
    match = re.search(r'<start_function_call>(.*?)<end_function_call>', raw, re.DOTALL)
    if not match:
        return None, {"error": "No function call found", "raw": raw}

    content = match.group(1).strip()

    name_match = re.search(r'call:(\w+)\{', content)
    if not name_match:
        return None, {"error": "Could not parse function name"}

    fn_name = name_match.group(1)

    args = {}
    for k, v in re.findall(r'(\w+):<escape>(.*?)<escape>', content):
        args[k] = v

    fn = TOOL_MAP.get(fn_name)
    if not fn:
        return None, {"error": f"Unknown function: {fn_name}"}

    return fn_name, fn(**args)


# ── Run it ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    while True:
        user_in = input("Type or Q to Quit: ")
        if user_in.strip().upper() == "Q":
            break
        run(user_in)