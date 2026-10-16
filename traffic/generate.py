"""Traffic generator: plays personas against the ShopWave Managed Agent.

The agent endpoint on DO Managed Agents is OpenAI-compatible, and a serverless
inference model plays the customer. Each session is an independent multi-turn
conversation, which Signals later stitches and triages.

Usage:
  export AGENT_ENDPOINT=https://xxxx.agents.do-ai.run   # from the agent's overview page
  export AGENT_KEY=...                                  # agent access key
  export SIM_ENDPOINT=https://inference.do-ai.run       # serverless inference
  export SIM_KEY=...                                    # model access key
  export SIM_MODEL=llama3.3-70b-instruct                # any chat model

  python generate.py --sessions 40 --mix all
  python generate.py --sessions 10 --persona timeout_trigger   # with FAIL_MODE=slow set on backend

Requires: pip install openai
"""
import argparse
import os
import random
import sys
import time

from openai import OpenAI
from personas import PERSONAS

MAX_TURNS = 8


def make_clients():
    agent = OpenAI(
        base_url=os.environ["AGENT_ENDPOINT"].rstrip("/") + "/api/v1",
        api_key=os.environ["AGENT_KEY"],
    )
    sim = OpenAI(
        base_url=os.environ.get("SIM_ENDPOINT", "https://inference.do-ai.run").rstrip("/") + "/v1",
        api_key=os.environ["SIM_KEY"],
    )
    return agent, sim


def run_session(agent, sim, persona_name, sim_model, verbose=True):
    p = PERSONAS[persona_name]
    agent_history = []          # what the agent sees (user/assistant)
    user_msg = p["opening"]

    for turn in range(MAX_TURNS):
        agent_history.append({"role": "user", "content": user_msg})
        if verbose:
            print(f"  [customer] {user_msg}")
        try:
            resp = agent.chat.completions.create(model="n/a", messages=agent_history)
            agent_msg = resp.choices[0].message.content or ""
        except Exception as e:
            print(f"  [agent error] {e}")
            break
        agent_history.append({"role": "assistant", "content": agent_msg})
        if verbose:
            print(f"  [agent]    {agent_msg[:200]}")

        # Simulator decides the customer's next message.
        sim_messages = [
            {"role": "system", "content": (
                f"You are role-playing a customer of an online store.\n"
                f"Goal: {p['goal']}\nBehavior: {p['style']}\n"
                "Reply with ONLY the customer's next message. "
                "If the conversation should end, reply with exactly: [END]"
            )}
        ]
        # replay transcript from the customer's perspective
        for m in agent_history:
            role = "assistant" if m["role"] == "user" else "user"
            sim_messages.append({"role": role, "content": m["content"]})
        nxt = sim.chat.completions.create(model=sim_model, messages=sim_messages, max_tokens=200)
        user_msg = (nxt.choices[0].message.content or "").strip()
        if "[END]" in user_msg or not user_msg:
            break
        time.sleep(0.5)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sessions", type=int, default=20)
    ap.add_argument("--persona", default=None, help="single persona name")
    ap.add_argument("--mix", default="all", help="'all' = weighted mix of personas")
    args = ap.parse_args()

    agent, sim = make_clients()
    sim_model = os.environ.get("SIM_MODEL", "llama3.3-70b-instruct")

    weights = {"happy": 4, "confused": 3, "angry": 3, "quitter": 2, "hasty_refund": 2}
    names = list(weights) if not args.persona else [args.persona]
    wts = [weights.get(n, 1) for n in names]

    for i in range(args.sessions):
        persona = args.persona or random.choices(names, weights=wts)[0]
        print(f"\n=== session {i+1}/{args.sessions} persona={persona} ===")
        try:
            run_session(agent, sim, persona, sim_model)
        except KeyboardInterrupt:
            sys.exit(0)
        except Exception as e:
            print(f"  session failed: {e}")


if __name__ == "__main__":
    main()
