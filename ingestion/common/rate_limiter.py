"""Simple placeholder rate limiter utilities."""

class RateLimiter:
    def __init__(self, rate_per_sec: float = 5.0):
        self.rate_per_sec = rate_per_sec

    def allow(self) -> bool:
        # Placeholder: always allow
        return True
