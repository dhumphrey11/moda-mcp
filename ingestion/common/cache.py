"""Simple in-memory cache placeholder."""

from typing import Any, Dict

class SimpleCache:
    def __init__(self):
        self.store: Dict[str, Any] = {}

    def get(self, key: str) -> Any:
        return self.store.get(key)

    def set(self, key: str, value: Any) -> None:
        self.store[key] = value
