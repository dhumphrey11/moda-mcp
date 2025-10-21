"""Shared ingestion utilities placeholder."""

import datetime as dt

def utc_now_iso() -> str:
    return dt.datetime.utcnow().replace(tzinfo=dt.timezone.utc).isoformat()
