from tools.base import Tool
import applescript_executor as ase


class SendMessageTool(Tool):
    name = "send_message"
    description = "Send an iMessage or text to a contact by name. Use when user says 'text X', 'message X', 'tell X that', 'let X know'."
    schema = '{"to":"contact name","message":"text to send"}'

    def execute(self, params: dict) -> tuple[str, list[dict]]:
        to = params.get("to", "")
        message = params.get("message", "")
        if not to or not message:
            return "Who should I text, and what should I say?", []
        return ase.send_message_to_contact(to, message), []
