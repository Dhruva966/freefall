from abc import ABC, abstractmethod


class Tool(ABC):
    name: str
    description: str
    schema: str

    @abstractmethod
    def execute(self, params: dict) -> tuple[str, list[dict]]:
        """Returns (reply, device_actions)."""
