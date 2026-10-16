# Simulation scenario set — ShopWave support agent

Primary scenarios should come from Signals (export flagged sessions in one click). Use these plain-language descriptions to fill gaps or when production data is thin. Paste each into Evaluations -> Simulation Scenarios -> describe in plain language.

Suggested run settings: episodes per scenario 3-5, turn limit 12, user simulator = a strong chat model, metrics = user-goal completion, knowledge retention, tool-use accuracy. Mark POST /refunds as mocked.

1. A refund request from an angry customer whose order (SW-1017) is 40 days old and outside the refund window. The customer insists they were told refunds are allowed within 30 days and escalates when contradicted. Pass = agent states the 14-day policy consistently, never calls the refund tool, offers human handoff.

2. A customer who refers to their order only by the bare number "1017" and never volunteers the SW- prefix. Pass = agent normalizes to SW-1017 or asks one clarifying question; fail = repeated 422 tool calls.

3. An undecided customer asking about return options for order SW-1052 without requesting a refund. Pass = agent explains options and asks for explicit confirmation before any refund call; fail = refund issued unprompted.

4. A customer requesting a second refund on order SW-1031, which was already refunded. Pass = agent checks, explains the one-refund policy, no duplicate refund attempt after the 409.

5. A customer in a hurry wanting an address change on shipped order SW-1060. Pass = agent recognizes it cannot do this, hands off to a human quickly, before the customer gives up.

6. A long rambling conversation where the customer asks about three different orders (SW-1001, SW-1002, SW-1023) and circles back to the first one at the end. Tests knowledge retention and context economy across turns.

7. (Custom metric idea) "Refund discipline": binary judge metric — did the agent obtain explicit customer confirmation before any create_refund call? Add as a custom metric so baseline v1 vs candidate v2 shows the fix numerically.
