"""ShopWave MCP server — registered in Action Gateway as a custom tool provider.

Action Gateway accepts remote MCP servers (Streamable HTTP), not OpenAPI specs,
so this wraps the store REST API and the DO Knowledge Base retrieve endpoint
as MCP tools. Runs as its own App Platform service on port 8080, MCP endpoint
path: /mcp

Env vars:
  STORE_API_URL    e.g. https://shopwave-demo-4xjia.ondigitalocean.app
  KB_RETRIEVE_URL  e.g. https://kbaas.do-ai.run/v1/<kb-uuid>/retrieve
  KB_ACCESS_KEY    knowledge base / model access key (Bearer token)
"""
import os

import httpx
from mcp.server.fastmcp import FastMCP

STORE = os.environ.get("STORE_API_URL", "http://localhost:8080").rstrip("/")
KB_URL = os.environ.get("KB_RETRIEVE_URL", "")
KB_KEY = os.environ.get("KB_ACCESS_KEY", "")

mcp = FastMCP("shopwave", host="0.0.0.0", port=8080)


async def _get(path: str) -> dict | list:
    async with httpx.AsyncClient(timeout=20) as c:
        r = await c.get(f"{STORE}{path}")
        if r.status_code >= 400:
            # surface API errors to the agent as tool errors with detail
            raise RuntimeError(f"HTTP {r.status_code}: {r.json().get('detail', r.text)}")
        return r.json()


@mcp.tool()
async def get_order(order_id: str) -> dict:
    """Look up a ShopWave order by its ID. Order IDs have the format SW-#### (e.g. SW-1001)."""
    return await _get(f"/orders/{order_id}")


@mcp.tool()
async def get_shipping_status(order_id: str) -> dict:
    """Get shipping/carrier status and tracking number for a ShopWave order (format SW-####)."""
    return await _get(f"/orders/{order_id}/shipping")


@mcp.tool()
async def list_customer_orders(email: str) -> list:
    """List all orders for a customer by their email address."""
    return await _get(f"/customers/{email}/orders")


@mcp.tool()
async def create_refund(order_id: str, reason: str, confirmed_by_customer: bool = False) -> dict:
    """Issue a refund for a ShopWave order. WRITE operation: moves real money.
    order_id must be format SW-####. Set confirmed_by_customer=true only after
    the customer has explicitly confirmed they want the refund."""
    async with httpx.AsyncClient(timeout=20) as c:
        r = await c.post(f"{STORE}/refunds", json={
            "order_id": order_id,
            "reason": reason,
            "confirmed_by_customer": confirmed_by_customer,
        })
        if r.status_code >= 400:
            raise RuntimeError(f"HTTP {r.status_code}: {r.json().get('detail', r.text)}")
        return r.json()


@mcp.tool()
async def search_knowledge_base(query: str) -> dict:
    """Search ShopWave's policy knowledge base (return/refund policy, shipping FAQ).
    Use this before answering any policy question."""
    if not KB_URL:
        raise RuntimeError("Knowledge base not configured")
    async with httpx.AsyncClient(timeout=20) as c:
        r = await c.post(
            KB_URL,
            headers={"Authorization": f"Bearer {KB_KEY}"},
            json={"query": query},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")
        return r.json()


if __name__ == "__main__":
    mcp.run(transport="streamable-http")
