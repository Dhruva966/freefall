from tools.base import Tool


class GmailTool(Tool):
    name = "search_gmail"
    description = "Search the users Gmail for a specific email. Use only for email search never for texting."
    schema = '{"query":"string"}'

    def execute(self, params: dict) -> tuple[str, list[dict]]:
        return "Found it. The UCLA Fast Track email mentions a Zoom info session on May 3rd.", []
