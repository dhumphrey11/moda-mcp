from fastapi import FastAPI
import asyncio
import json
import logging
from datetime import datetime, timezone
from collections import defaultdict

import websockets
import httpx
from dateutil import parser
from google.cloud import bigquery

app = FastAPI(title="ingestion-coinbase")

logger = logging.getLogger("ingestion.coinbase")
logging.basicConfig(level=logging.INFO)


COINBASE_WS_URL = "wss://ws-feed.exchange.coinbase.com"
COINBASE_REST_TICKER = "https://api.exchange.coinbase.com/products/{product_id}/ticker"

# Product to subscribe; could be param/config
PRODUCT_ID = "BTC-USD"

# Aggregation storage: map hour_start -> OHLCV
class OHLCV:
    def __init__(self):
        self.open = None
        self.high = None
        self.low = None
        self.close = None
        self.volume = 0.0

    def add_tick(self, price: float, size: float):
        if self.open is None:
            self.open = price
        self.high = price if (self.high is None or price > self.high) else self.high
        self.low = price if (self.low is None or price < self.low) else self.low
        self.close = price
        self.volume += size

    def to_row(self, symbol: str, ts: datetime):
        return {
            "timestamp": ts.isoformat(),
            "symbol": symbol,
            "open": float(self.open) if self.open is not None else None,
            "high": float(self.high) if self.high is not None else None,
            "low": float(self.low) if self.low is not None else None,
            "close": float(self.close) if self.close is not None else None,
            "volume": float(self.volume),
        }


class CoinbaseIngestor:
    def __init__(self, product_id: str = PRODUCT_ID):
        self.product_id = product_id
        self.running = False
        self.agg = defaultdict(OHLCV)
        self.bq_client = bigquery.Client()
        self.dataset = "moda_mcp"
        self.table = "raw_ohlcv"

    async def connect_ws(self):
        async with websockets.connect(COINBASE_WS_URL) as ws:
            # Subscribe to ticker or matches
            sub = {
                "type": "subscribe",
                "product_ids": [self.product_id],
                "channels": ["matches"]
            }
            await ws.send(json.dumps(sub))
            logger.info("Subscribed to WS matches for %s", self.product_id)

            async for msg in ws:
                try:
                    data = json.loads(msg)
                except Exception:
                    continue
                # match messages represent trades
                if data.get("type") == "match":
                    await self.handle_trade_msg(data)

    async def rest_get_ticker(self):
        url = COINBASE_REST_TICKER.format(product_id=self.product_id)
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(url)
            r.raise_for_status()
            return r.json()

    async def handle_trade_msg(self, data: dict):
        # fields: price, size, time
        price = float(data.get("price"))
        size = float(data.get("size", 0.0))
        t = parser.isoparse(data.get("time"))
        # normalize to hour start
        hour_ts = t.replace(minute=0, second=0, microsecond=0, tzinfo=timezone.utc)
        key = hour_ts.isoformat()
        self.agg[key].add_tick(price, size)
        # Optionally flush older buckets
        await self.maybe_flush_old_buckets()

    async def maybe_flush_old_buckets(self):
        # Flush any completed hour buckets (older than current hour)
        now = datetime.now(timezone.utc)
        current_hour = now.replace(minute=0, second=0, microsecond=0)
        to_flush = [k for k in self.agg.keys() if parser.isoparse(k) < current_hour]
        rows = []
        for k in to_flush:
            dt = parser.isoparse(k)
            o = self.agg.pop(k)
            rows.append(o.to_row(self.product_id, dt))

        if rows:
            await asyncio.get_event_loop().run_in_executor(None, self.write_rows_bq, rows)

    def write_rows_bq(self, rows):
        # Insert into BigQuery table moda_mcp.raw_ohlcv
        table_id = f"{self.bq_client.project}.{self.dataset}.{self.table}"
        errors = self.bq_client.insert_rows_json(table_id, rows)
        if errors:
            logger.error("BigQuery insert errors: %s", errors)
        else:
            logger.info("Inserted %d rows into %s", len(rows), table_id)

    async def run(self):
        self.running = True
        while self.running:
            try:
                await self.connect_ws()
            except Exception as e:
                logger.warning("WS connect failed: %s - falling back to REST tick poll", e)
                # REST fallback: poll ticker every 5s
                try:
                    ticker = await self.rest_get_ticker()
                    price = float(ticker.get("price"))
                    size = float(ticker.get("size", 0.0))
                    time_str = ticker.get("time") or ticker.get("trade_id")
                    t = parser.isoparse(ticker.get("time")) if ticker.get("time") else datetime.now(timezone.utc)
                    hour_ts = t.replace(minute=0, second=0, microsecond=0, tzinfo=timezone.utc)
                    key = hour_ts.isoformat()
                    self.agg[key].add_tick(price, size)
                    await self.maybe_flush_old_buckets()
                except Exception as re:
                    logger.error("REST fallback failed: %s", re)
                await asyncio.sleep(5)


ingestor = CoinbaseIngestor()


@app.on_event("startup")
async def startup_event():
    # Start background task
    loop = asyncio.get_event_loop()
    loop.create_task(ingestor.run())


@app.get("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
