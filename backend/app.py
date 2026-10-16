"""ShopWave Store API — the Action Gateway tool target for the Managed Agent PoC.

Failure injection via env var FAIL_MODE:
  none  : normal behavior
  slow  : shipping lookups sleep 25s  -> Environmental signals (tool timeouts)
  flaky : order lookups fail 1 in 3   -> Execution signals (retries)

Strict order-ID validation (must match SW-\\d+) is intentional: agent v1 passes
bare numeric IDs, producing 422s and retry loops that Signals flags.
"""
import os
import json
import random
import time
from datetime import datetime, timedelta, timezone

import asyncpg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://localhost/shopwave")
FAIL_MODE = os.environ.get("FAIL_MODE", "none")
REFUND_WINDOW_DAYS = 14  # the REAL policy (agent v1 wrongly says 30)

app = FastAPI(title="ShopWave Store API", version="1.0.0")
pool = None


@app.on_event("startup")
async def startup():
    global pool
    pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=5)


class RefundRequest(BaseModel):
    order_id: str = Field(..., description="Order ID, format SW-####")
    reason: str = Field(..., min_length=3)
    confirmed_by_customer: bool = Field(False, description="Customer explicitly confirmed the refund")


def validate_order_id(order_id: str) -> str:
    if not order_id.startswith("SW-") or not order_id[3:].isdigit():
        raise HTTPException(
            status_code=422,
            detail=f"Invalid order_id '{order_id}'. Expected format: SW-#### (e.g. SW-1001).",
        )
    return order_id


@app.get("/health")
async def health():
    return {"status": "ok", "fail_mode": FAIL_MODE}


@app.get("/orders/{order_id}")
async def get_order(order_id: str):
    order_id = validate_order_id(order_id)
    if FAIL_MODE == "flaky" and random.random() < 0.33:
        raise HTTPException(status_code=503, detail="Upstream inventory service unavailable")
    async with pool.acquire() as con:
        row = await con.fetchrow(
            """SELECT o.*, c.full_name, c.email FROM orders o
               JOIN customers c ON c.id = o.customer_id WHERE o.order_id = $1""",
            order_id,
        )
    if not row:
        raise HTTPException(status_code=404, detail=f"Order {order_id} not found")
    d = dict(row)
    d["items"] = json.loads(d["items"])
    d["total_usd"] = float(d["total_usd"])
    for k in ("ordered_at", "delivered_at"):
        if d.get(k):
            d[k] = d[k].isoformat()
    return d


@app.get("/orders/{order_id}/shipping")
async def get_shipping(order_id: str):
    order_id = validate_order_id(order_id)
    if FAIL_MODE == "slow":
        time.sleep(25)  # deliberately blocks -> tool timeout upstream
    async with pool.acquire() as con:
        row = await con.fetchrow(
            "SELECT order_id, status, carrier, tracking_number, delivered_at FROM orders WHERE order_id=$1",
            order_id,
        )
    if not row:
        raise HTTPException(status_code=404, detail=f"Order {order_id} not found")
    d = dict(row)
    if d.get("delivered_at"):
        d["delivered_at"] = d["delivered_at"].isoformat()
    return d


@app.post("/refunds")
async def create_refund(req: RefundRequest):
    order_id = validate_order_id(req.order_id)
    async with pool.acquire() as con:
        order = await con.fetchrow("SELECT * FROM orders WHERE order_id=$1", order_id)
        if not order:
            raise HTTPException(status_code=404, detail=f"Order {order_id} not found")
        existing = await con.fetchval("SELECT count(*) FROM refunds WHERE order_id=$1", order_id)
        if existing:
            raise HTTPException(status_code=409, detail=f"Order {order_id} already has a refund on file")
        cutoff = datetime.now(timezone.utc) - timedelta(days=REFUND_WINDOW_DAYS)
        if order["ordered_at"] < cutoff:
            raise HTTPException(
                status_code=403,
                detail=f"Order {order_id} is outside the {REFUND_WINDOW_DAYS}-day refund window",
            )
        row = await con.fetchrow(
            "INSERT INTO refunds (order_id, amount_usd, reason) VALUES ($1,$2,$3) RETURNING id, created_at",
            order_id, order["total_usd"], req.reason,
        )
    return {
        "refund_id": row["id"],
        "order_id": order_id,
        "amount_usd": float(order["total_usd"]),
        "status": "issued",
        "created_at": row["created_at"].isoformat(),
    }


@app.get("/customers/{email}/orders")
async def list_customer_orders(email: str):
    async with pool.acquire() as con:
        rows = await con.fetch(
            """SELECT o.order_id, o.status, o.total_usd, o.ordered_at FROM orders o
               JOIN customers c ON c.id=o.customer_id WHERE c.email=$1 ORDER BY o.ordered_at DESC""",
            email.lower(),
        )
    if not rows:
        raise HTTPException(status_code=404, detail=f"No orders found for {email}")
    return [
        {"order_id": r["order_id"], "status": r["status"],
         "total_usd": float(r["total_usd"]), "ordered_at": r["ordered_at"].isoformat()}
        for r in rows
    ]
