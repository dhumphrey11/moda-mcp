"""Feature computation utilities (placeholder)."""

def simple_sma(values, window):
    if not values or window <= 0:
        return []
    out = []
    for i in range(len(values)):
        start = max(0, i - window + 1)
        window_vals = values[start:i+1]
        out.append(sum(window_vals) / len(window_vals))
    return out
