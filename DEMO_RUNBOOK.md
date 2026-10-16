# Demo runbook: Signals and Simulations (ShopWave)

Target length: 20-25 minutes. Pre-demo: agent v1 live, 40+ generated sessions processed by Signals (enable Signals at least a few hours before, processing can take up to an hour to begin), scenario set saved, one baseline simulation run on v1 already completed (runs take time, never run them live for the first time).

## 1. Set the trap (3 min)
Open the ShopWave chat frontend. Say: "This is a support agent my customer shipped. Uptime 100%, latency fine, every tool call returns 200. By every classic dashboard it is healthy." Hold one live conversation as the undecided customer: "I'm thinking about maybe returning my speaker, order SW-1052, what are my options?" Agent v1 fires the refund without confirmation. Pause on that: "A refund just went out that the customer never asked for. No alert fired anywhere."

## 2. Signals: find it at scale (6 min)
Console -> Harness Runtime -> Signals tab.
- Show the trend view: Interaction, Execution, Environmental.
- Drill into the Execution cluster: retry loops on get_order with bare IDs ("1017"). Point out the 422s that classic monitoring calls "client errors, working as intended".
- Drill into Interaction: sessions where users corrected the agent on refund policy, escalation requests, rage-quits.
- Talking points: nothing was instrumented, Harness Runtime and Action Gateway already emit these events; triage is a cheap first pass, not an LLM judge on 100 GB/s of traces (cite the Signals paper: 82% informativeness, 1.52x over random sampling); PII redacted, data stays in the team boundary, never cross-customer training.

## 3. One click to scenarios (2 min)
From a flagged wrong-refund session, click export to Evaluations. "That support ticket just became a test case. No test-data engineering."

## 4. Simulations: prove the fix (7 min)
Evaluations -> Simulations.
- Show the scenario set: Signals-derived plus plain-language ones (open simulations/scenarios.md item 1 as the example you typed in English).
- Show the pre-run baseline results for v1: low goal completion, refund-discipline metric failing.
- Show v2's run (diff the two prompts side by side first, 30 seconds: fixed policy, ID normalization, confirmation gate, retry cap).
- Emphasize: same harness and Action Gateway tools as production, candidate runs sandboxed, the refund tool is mocked so no money moves, each scenario plays multiple episodes and the user simulator takes different paths.
- Compare runs: goal completion up, tool-use errors gone, and the judge can tell reasoning failures from tool failures because every tool call is in the trajectory.

## 5. Close the loop (3 min)
"v2 ships. Signals keeps watching, trends flatten. The scenario set is locked and saved, so it is the regression suite for the next change, including when they fine-tune the model itself." If asked about pricing: usage-based, and Agent Droplets plans discount scenario generation, user simulation, and LLM judging (Pro 15%, Team 20%).

## Likely customer questions
- "We use LangChain/CrewAI" -> not supported in this preview; supported harnesses include Claude Code, Codex, OpenCode on Harness Runtime. Migration path discussion.
- "Single model comparison?" -> single-turn Evaluations remains the right tool; Simulations is for multi-turn agent behavior.
- "Data privacy?" -> opt-in, PII redaction before processing, team-boundary isolation, no cross-customer training.
- "Can we use the data for training?" -> yes, Signals data can be downloaded for fine-tuning or as reward/preference data for RL.

## Reset between demos
- Delete refunds created during demo: `DELETE FROM refunds WHERE order_id <> 'SW-1031';`
- Set backend FAIL_MODE back to none.
- Keep the Signals history: older trends make the dashboard look lived-in.
