# ShopWave Demo — DigitalOcean Signals & Simulations PoC

A full-stack PoC for demoing [DO Signals and Simulations](https://www.digitalocean.com/blog/introducing-signals-and-simulations): an e-commerce support agent with planted flaws (v1), caught by Signals in production traffic, fixed (v2), and validated through Simulations before shipping.

Start with **PLAYBOOK.md** — the end-to-end setup guide with every gotcha documented. **PLAN.md** has the architecture and rationale, **DEMO_RUNBOOK.md** the customer demo script.

## Layout

| Path | What |
|---|---|
| `backend/` | ShopWave store API (FastAPI) — the Action Gateway tool target. `seed_full.sql` = DB seed (25 customers, 60 orders) |
| `agent/` | System prompts v1 (buggy) / v2 (fixed), Action Gateway OpenAPI spec, knowledge base docs |
| `traffic/` | Persona-based traffic generator that drives Signals |
| `simulations/` | Plain-language scenario set for Evaluations → Simulations |
| `frontend/` | Chat UI for App Platform |
| `.do/app.yaml` | App Platform spec for the store API |

## Deploy the store API (Phase 2)

```bash
doctl apps create --spec .do/app.yaml
# then set the real DATABASE_URL secret in the console (Apps → shopwave-demo → store-api → Environment Variables)
```

Smoke test once live:

```bash
BASE=https://<your-app>.ondigitalocean.app
curl $BASE/health
curl $BASE/orders/SW-1017          # 40-day-old order (refund-ineligible)
curl $BASE/orders/1017             # 422 — planted trap for agent v1
curl "$BASE/customers/maya.chen@example.com/orders"
```

## Failure injection

Set env var `FAIL_MODE` on the store-api component: `none` (default), `slow` (shipping lookups hang 25s → tool timeouts), `flaky` (order lookups fail 1 in 3 → retry loops).
