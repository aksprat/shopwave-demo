# ShopWave PoC: Signals and Simulations on DigitalOcean

A full-stack, demo-ready proof of concept for DigitalOcean Signals and Simulations, built around a realistic e-commerce customer support agent. The story: ShopWave (a fictional online store) ships a support agent, Signals catches it misbehaving in production, Simulations proves the fix works before it ships.

## Why this scenario works for a demo

The agent has deliberate, controllable flaws (version 1) and a corrected configuration (version 2). That gives you a reproducible narrative that exercises every Signals category and the full Simulations loop:

1. Run agent v1 behind a real chat frontend, drive traffic at it.
2. Signals flags frustrated users (Interaction), tool retry loops and invalid arguments (Execution), and timeouts/context overflow (Environmental).
3. Export flagged sessions as evaluation scenarios in one click.
4. Run Simulations: v1 as baseline vs v2 as candidate, graded on user-goal completion, knowledge retention, tool-use accuracy.
5. Ship v2. Keep the scenarios as regression tests.

## Architecture

```
Customer browser
      |
App Platform (chat frontend, static + small API proxy)
      |
Managed Agents (Harness Runtime)  <-- system prompt v1 / v2
      |
Action Gateway  --> ShopWave Store API (App Platform, FastAPI)
      |                   |
      |             Managed PostgreSQL (orders, customers, refunds)
      |
Knowledge Base  <-- return policy, shipping FAQ docs (stored in Spaces)
      |
Inference Engine (serving the agent model)

Signals: watches Harness Runtime + Action Gateway events (nothing to instrument)
Simulations: runs v2 candidate in sandboxed Harness Runtime, write-tools mocked
```

DO services used: Managed Agents (Harness Runtime + Action Gateway), Inference Engine, Signals, Evaluations + Simulations, App Platform (x2 apps), Managed PostgreSQL, Knowledge Bases, Spaces.

## Repo layout

```
backend/            FastAPI ShopWave store API (tools target) + Dockerfile
  app.py            Order lookup, shipping, refunds, with failure injection
  schema.sql        Postgres schema + seed data
agent/
  system_prompt_v1.md   The "buggy" production config
  system_prompt_v2.md   The fixed candidate
  openapi.yaml          Tool spec registered in Action Gateway
  kb/                   Knowledge base docs (return policy, shipping FAQ)
traffic/
  personas.py       User personas (happy, confused, angry, quitter)
  generate.py       Drives multi-turn conversations at the agent endpoint
simulations/
  scenarios.md      Plain-language scenario set for the Simulations UI
frontend/
  index.html        Chat UI (single file, deploy to App Platform static site)
DEMO_RUNBOOK.md     What to click and say during the customer demo
```

## The planted failures (what Signals should catch)

| Flaw in v1 | Mechanism | Signals category |
|---|---|---|
| Agent passes order ID without the "SW-" prefix | Store API rejects bare IDs with 422; agent retries blindly | Execution: invalid arguments, retry loop |
| Refund policy misstated in prompt (30 days vs actual 14) | Agent promises refunds the API denies; users push back, correct it, escalate | Interaction: corrections, escalations |
| No instruction to confirm before refund | Refunds fired on first mention; wrong refunds go out | Interaction + business risk (the demo hook) |
| Backend FAIL_MODE=slow makes shipping lookups hang | Tool timeouts under load | Environmental: timeouts |
| Verbose prompt + no summarization instruction | Long sessions overflow context | Environmental: context overflow |

v2 fixes all five: correct policy, ID normalization rule, confirmation step before refunds, concise responses, and you flip the backend out of slow mode (infra fix shown alongside the prompt fix).

## Build phases

### Phase 1: Data layer (~1 hr)
1. Create Managed PostgreSQL (smallest plan). Load `backend/schema.sql` — 25 customers, 60 orders across statuses, refund history.
2. Create a Spaces bucket, upload `agent/kb/*` docs, create a Knowledge Base from the bucket, index it.

### Phase 2: Store API (~1 hr)
3. Deploy `backend/` to App Platform from your GitHub repo (or `doctl apps create`). Set `DATABASE_URL` and `FAIL_MODE=none`.
4. Smoke test: `GET /orders/SW-1017`, `POST /refunds` etc.

### Phase 3: Agent (~1-2 hrs)
5. Create a Managed Agent on Harness Runtime. Model via Inference Engine (pick a mid-size model from the Model Library; flaws show better on smaller models).
6. Paste `system_prompt_v1.md`. Attach the Knowledge Base.
7. Register `agent/openapi.yaml` in Action Gateway pointing at the store API. Mark `POST /refunds` as a write tool (Simulations will mock it later).
8. Test in the console playground: ask about order SW-1017.

### Phase 4: Frontend (~30 min)
9. Deploy `frontend/index.html` to App Platform as a static site, with the agent endpoint + key set in the small proxy (or call the agent endpoint from a tiny API route to keep the key off the client).

### Phase 5: Signals (~1 hr + wait)
10. Console -> Data & Learning -> Signals. Enable for your agent. Processing can take up to an hour to begin, so do this before generating traffic.
11. Run the traffic generator: `python traffic/generate.py --sessions 40 --mix all`. Mid-run, set `FAIL_MODE=slow` on the backend for 10 sessions to plant Environmental signals, then revert.
12. Also hold 3-4 manual conversations through the frontend (these are your live-demo sessions).
13. Review the Signals tab: trends across Interaction / Execution / Environmental. Drill into flagged sessions. Export the best ones (wrong-refund, retry-loop, rage-quit) to Evaluations as scenarios.

### Phase 6: Simulations (~1-2 hrs)
14. In Evaluations -> Simulation Scenarios: you now have Signals-derived scenarios. Add 2-3 plain-language ones from `simulations/scenarios.md` (e.g. "a refund request from an angry customer with missing order details").
15. Run simulation #1: candidate = agent v1 (baseline). Episodes per scenario: 3-5, turn limit ~12. Metrics: user-goal completion, knowledge retention, tool-use accuracy. Expect poor scores.
16. Create agent v2 with `system_prompt_v2.md` (or a new version of the same agent). Run simulation #2 against the same scenario set with write-tools mocked.
17. Compare runs: v2 improves on exactly the failure classes Signals surfaced. Save the scenario set to your library as regression tests (sets lock after a run; duplicate to revise).

### Phase 7: Close the loop
18. Ship v2 behind the frontend. Re-run light traffic. Signals trends flatten. That before/after is the closing slide of your demo.

## Budget and timeline

Roughly a day and a half of build time end to end. Monthly cost is small: smallest Managed Postgres, two basic App Platform apps, Spaces, plus usage-based agent/inference/simulation charges. An Agent Droplets plan (Pro/Team) discounts scenario generation, user simulation, and LLM judging, worth mentioning to customers.

## Demo narrative in one paragraph

"Your agent passed every test and the dashboards are green, yet refunds are going out that should not. Standard observability cannot see that. Watch: Signals flagged 14 sessions this week where users corrected the agent on refund policy, and a retry-loop cluster on order lookups. One click turns those sessions into test scenarios. We fix the prompt, run the fix through Simulations against those exact scenarios with money-moving tools mocked, and the grader shows goal completion up and tool errors gone, before any real user touches it. That is the loop: Signals finds it, Simulations proves the fix, ship with confidence."

See DEMO_RUNBOOK.md for the click-by-click version.
