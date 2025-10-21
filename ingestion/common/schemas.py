"""Pydantic models for ingestion events (placeholder)."""

from pydantic import BaseModel

class PriceTick(BaseModel):
    symbol: str
    price: float
    ts: int  # epoch ms
