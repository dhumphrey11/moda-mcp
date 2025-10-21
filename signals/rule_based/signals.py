"""Rule-based breakout signal placeholders."""

from typing import List


def breakout_signal(prices: List[float], lookback: int = 20) -> bool:
    if not prices or lookback <= 0 or len(prices) < lookback:
        return False
    window = prices[-lookback:]
    return prices[-1] >= max(window)
