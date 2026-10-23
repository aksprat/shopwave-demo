# ShopWave PoC Playbook — DigitalOcean Signals & Simulations, end to end

A battle-tested walkthrough for standing up the ShopWave demo: a customer support agent with deliberately planted flaws (v1), caught by **Signals** in production traffic, fixed (v2), and validated with **Simulations** before shipping. Every gotcha in here was hit for real during the first build, so follow the order.

Repo: https://github.com/aksprat/shopwave-demo
Companion docs: `PLAN.md` (architecture and rationale), `DEMO_RUNBOOK.md` (customer demo talk track).

---

## What you're building

```
Customer / traffic generator
      |
Harness Runtime (OpenCode harness + Serverless Inference model)
      |  preloaded tools
Action Gateway  ──>  shopwave MCP server (App Platform /mcp)
                          |                  |
                     Store API          KB retrieve endpoint
                   (App Platform)        (kbaas.do-ai.run)
                          |
                  Managed PostgreSQL

Signals: opt-in, watches Harness Runtime sessions
Simulations: Evaluations → runs v1 (baseline) vs v2 (fix) on the same tools, write-tool mocked
```

The planted flaws in agent v1 (see `agent/system_prompt_v1.md`):

| Flaw | What happens | Signals category |
|---|---|---|
| Wrong refund policy (30d vs real 14d) | Agent promises refunds the API denies; users correct/escalate | Interaction |
| No confirmation before refunds | Refunds fire on first mention | Interaction + business risk |
| No order-ID normalization | "order 1017" → 422 → blind retries | Execution |
| "Retry, it's probably temporary" | Retry loops on hard failures | Execution |
| Maximal verbosity | Context bloat on long sessions | Environmental |
| Backend `FAIL_MODE=slow` | 25s shipping lookups → timeouts | Environmental |

---

## Prerequisites

- DO team where you are an **owner** (needed for team-scoped Action Gateway providers)
- `doctl` recent build (`doctl harness-runtime --help` must work), authenticated
- `psql` locally (`brew install libpq && brew link --force libpq` on macOS)
- Funds/balance for Harness Runtime; a Serverless Inference **model access key**
- Fork or clone of this repo connected to your own GitHub account (App Platform deploys from it)

---

## Phase 1 — Database and Knowledge Base (~30 min)

1. Create a **Managed PostgreSQL** cluster (smallest plan). Region matters: keep everything in one region (we used `ric1`).
2. Load the seed data (25 customers, 60 orders, 8 refunds; dates are relative to load time so refund-window scenarios always hold):
   ```bash
   psql "<your-connection-string>" -f backend/seed_full.sql
   ```
   Sanity check prints `customers 25 / orders 60 / refunds 8`.
3. Create a **Spaces bucket**, upload `agent/kb/return_policy.md` and `agent/kb/shipping_faq.md`.
4. Create a **Knowledge Base** (Data & Learning) with the bucket as data source. Wait for indexing. Note the **retrieve endpoint**: `https://kbaas.do-ai.run/v1/<kb-uuid>/retrieve`.

> Security: never paste the doadmin connection string into chats/docs you'll share. Create a scoped DB user for the app, and rotate any credential that leaks.

## Phase 2 — Store API + MCP server on App Platform (~45 min)

The app has two components from one repo: `store-api` (FastAPI REST, the system of record) and `mcp-server` (MCP wrapper that Action Gateway consumes; Action Gateway accepts **MCP servers only**, not OpenAPI specs).

1. Edit `.do/app.yaml`: set your region, repo, and the KB retrieve URL.
2. Create the app: `doctl apps create --spec .do/app.yaml` (or console → Create App from GitHub).
3. In the console, on each component set the real secrets (**component-level**, not app-level — component-level placeholders override app-level values, a classic trap):
   - `store-api` → `DATABASE_URL` = your connection string, no surrounding quotes
   - `mcp-server` → `KB_ACCESS_KEY` = your model access key
4. Gotchas we hit, so you don't:
   - **App Platform does not re-read `.do/app.yaml` from the repo on push.** The spec lives in the platform. Adding/changing components = edit via console App Spec editor or `doctl apps update`. Pushes only redeploy code.
   - **Dependency pins matter.** `requirements.txt` pins `pydantic==2.11.*`, `mcp==1.13.*`, `uvicorn>=0.31.1` — compatible set. Loosening them reproduces two build/boot failures we debugged (pydantic internal API removed; uvicorn conflict).
   - The **ingress rules** route `/mcp` (with `preserve_path_prefix`) to mcp-server and everything else to store-api, so both share one domain.
5. Smoke test:
   ```bash
   BASE=https://<your-app>.ondigitalocean.app
   curl $BASE/health                 # {"status":"ok","fail_mode":"none"}
   curl $BASE/orders/SW-1017         # 40-day-old order, refund-INeligible
   curl $BASE/orders/1017            # 422 — intentional trap for agent v1
   curl -i $BASE/mcp                 # any 4xx = MCP server alive (it wants a real MCP handshake)
   ```

## Phase 3 — Action Gateway + Harness Runtime (~45 min)

**Register the MCP provider (must be team-scoped):**

1. Console → Managed Agents → Action Gateway → Tools → **Add custom provider**.
2. Name `shopwave`, endpoint `https://<your-app>.ondigitalocean.app/mcp`, auth **None**.
3. **Register with team scope.** A user-scoped provider fails at runtime with `provider was registered by another user and is not shared with your team`, because Harness sessions call the gateway under a different identity than your console user. Team owners get the scope option; if you don't see it, check your team context.
4. Connect and discover; enable all five tools. Slugs come out as `shopwave_get_order`, `shopwave_get_shipping_status`, `shopwave_list_customer_orders`, `shopwave_create_refund`, `shopwave_search_knowledge_base`.

**Create the v1 environment:**

Use the YAML spec, not the console form — the console tool picker can't **preload** tools, and without preloading mid-size models fumble the `action_search`/`action_invoke` discovery chain (we watched one die doing exactly that).

```bash
export HARNESS_INFERENCE_API_KEY=<your-model-access-key>
doctl harness-runtime launch agent/environment_v1.yaml
```

Notes:
- **Model must be serverless-capable.** Check the Supported Models docs for the Serverless column. Llama 3.1 8B is dedicated-only and fails at runtime with a confusing `404 model not found` (console lets you pick it anyway — bug reported). Known-good: `llama-4-maverick`, `deepseek-v4-flash-0731`, `mistral-3-14B`.
- The system prompt lives as an **inline skill** in the spec (there is no "system prompt" field in Harness Runtime).
- `permissions.default: allow` is deliberate for v1 — the missing refund confirmation is a *conversational* flaw we want Signals to catch; a platform approval prompt would mask it.
- **Environments are immutable.** Any change (model, tools, skill text) = new environment. That's a feature here: v1 and v2 stay cleanly separate for Simulations.

**Verify:** in a session, ask `What is the status of order SW-1017?` → expect a direct `shopwave_get_order` call and a correct answer. Then `I want a refund for SW-1017, the mugs arrived chipped` → v1 promises the 30-day window, calls `create_refund`, API returns 403 (40 days old). That contradiction is planted Signals material.

## Phase 4 — Enable Signals BEFORE generating traffic

Signals is **opt-in and not retroactive**: sessions run before you enable it are never processed, and processing takes up to an hour to begin. Do this before any bulk traffic.

1. Console → Data & Learning → Signals (or Harness Runtime → Signals tab).
2. Enable for your environment/agent.
3. Go get coffee or build Phase 5 while it warms up.

## Phase 5 — Generate traffic

Scripted personas (see `traffic/personas.py` — each persona targets a specific signal category):

```bash
pip install openai
export AGENT_ENDPOINT=<agent endpoint>  AGENT_KEY=<key>
export SIM_ENDPOINT=https://inference.do-ai.run  SIM_KEY=<model access key>
export SIM_MODEL=llama-4-maverick
python traffic/generate.py --sessions 40 --mix all
```

Mid-run, plant the Environmental signals: set `FAIL_MODE=slow` on the store-api component (console env var → redeploys), run `--persona timeout_trigger --sessions 10`, set it back to `none`.

Add 3-5 manual conversations too — those are your live-demo sessions. Then review the Signals view: Interaction / Execution / Environmental trends, drill into flagged sessions, and **export the best ones to Evaluations** (wrong-refund, retry-loop, rage-quit).

## Phase 6 — Fix and prove it with Simulations

1. Create the v2 environment: copy `agent/environment_v1.yaml`, swap the skill instructions for `agent/system_prompt_v2.md` (correct 14-day policy, ID normalization, confirmation gate before refunds, retry cap, concise style), name it `shopwave-support-v2`, launch.
2. Evaluations → Simulation Scenarios: use the Signals-exported scenarios plus plain-language ones from `simulations/scenarios.md`.
3. Run simulation #1 with **v1 as candidate** (baseline). Episodes per scenario 3-5, turn limit 12. Metrics: user-goal completion, knowledge retention, tool-use accuracy; add the custom "refund discipline" metric from `simulations/scenarios.md`. **Mock `shopwave_create_refund`** in the run setup (there's no "write tool" flag at registration; mocking is chosen per-run).
4. Run simulation #2 with **v2 as candidate**, same scenario set. Compare: goal completion up, tool errors gone, refund discipline passing.
5. Save the scenario set as regression tests (sets lock after a run; duplicate to revise).
6. Point traffic/frontend at v2, let Signals confirm the trends flatten.

Never run a simulation live for the first time in front of a customer — pre-run both, demo the comparison.

## Demo day

Follow `DEMO_RUNBOOK.md`. Reset between demos:
```sql
DELETE FROM refunds WHERE order_id <> 'SW-1031';
```
and confirm `FAIL_MODE=none`.

## Troubleshooting index (all hit in anger)

| Symptom | Cause | Fix |
|---|---|---|
| Deploy fails: `invalid DSN: scheme expected` | `DATABASE_URL` still a placeholder; component-level env overrides app-level | Set the secret on the **component** |
| Build fails: pydantic/mcp/uvicorn conflicts | Loosened version pins | Keep the pins in `requirements.txt` |
| Session: `404 model not found` | Model not available on Serverless Inference | Pick a serverless-capable model; new environment |
| Tool calls: `provider registered by another user` | Action Gateway provider is user-scoped | Re-register provider with **team scope** |
| Agent searches catalog instead of calling tools, stalls | Tools not preloaded | Use YAML spec with `preload_tools` |
| Push rejected / git lock files | Repo initialized with README on GitHub; stale `.lock` files | `git push --force` once on a fresh repo; `find .git -name "*.lock" -delete` |
| New component missing after push | Platform spec ≠ repo spec | Console App Spec editor or `doctl apps update` |
| Nothing in Signals | Not enabled before traffic, or <1h since enabling | Enable first, wait, regenerate traffic |

## Cost notes

Smallest Managed Postgres, two small App Platform instances, Spaces, plus usage-based inference/agent/simulation charges. Agent Droplets plans discount scenario generation, user simulation, and LLM judging (Pro 15%, Team 20%).
