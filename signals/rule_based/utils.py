"""Utilities for rule-based signals (placeholder)."""

def normalize_series(xs):
    if not xs:
        return []
    mn, mx = min(xs), max(xs)
    if mx == mn:
        return [0.0 for _ in xs]
    return [(x - mn) / (mx - mn) for x in xs]
