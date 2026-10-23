"""Bulk traffic generator for Harness Runtime sessions (Signals feeding).

Each conversation = one fresh Harness session (so Signals sees distinct
sessions), driven turn-by-turn by a persona simulator on Serverless Inference.

Flow per session:
  POST /v2/agents/sessions {name, config_id}   -> session_id
  wait until session status is RUNNING
  loop: POST .../input {"text": msg} -> read SSE .../events until run ends
        -> feed agent reply to persona simulator -> next customer message
  DELETE /v2/agents/sessions/{session_id}

Env vars:
  DIGITALOCEAN_TOKEN   API token with agent scopes
  CONFIG_ID            Environment Config UUID (list: GET /v2/agents/configs,
                       or run with --list-configs)
  SIM_KEY              Serverless Inference model access key
  SIM_MODEL            default: llama-4-maverick

Usage:
  python generate_harness.py --list-configs
  python generate_harness.py --sessions 20 --mix all
  python generate_harness.py --sessions 5 --persona timeout_trigger
Requires: pip install httpx openai
"""
import argparse
import json
import os
import random
import sys
import time

import httpx
from openai import OpenAI
from personas import PERSONAS

API = "https://api.digitalocean.com"
TOKEN = os.environ.get("DIGITALOCEAN_TOKEN", "")
HDRS = {"Authorization": f"Bearer {TOKEN}"}
MAX_TURNS = 8
RUN_TIMEOUT = 120  # seconds to wait for the agent to finish a turn


def list_configs():
    r = httpx.get(f"{API}/v2/agents/configs", headers=HDRS, timeout=30)
    r.raise_for_status()
    data = r.json()
    for c in data.get("configs", data.get("environment_configs", [])) or []:
        print(f"{c.get('config_id', c.get('id'))}  {c.get('name')}")


def create_session(config_id: str, name: str) -> str:
    r = httpx.post(f"{API}/v2/agents/sessions", headers=HDRS, timeout=60,
                   json={"name": name, "config_id": config_id})
    r.raise_for_status()
    body = r.json()
    sess = body.get("session", body)
    return sess.get("session_id") or sess.get("id")


def wait_running(session_id: str, timeout=300):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        r = httpx.get(f"{API}/v2/agents/sessions/{session_id}", headers=HDRS, timeout=30)
        status = str(r.json().get("session", r.json()).get("status", ""))
        if status != last:
            print(f"    status: {status}")
            last = status
        if any(s in status for s in ("READY", "RUNNING", "ACTIVE")):
            return
        if any(s in status for s in ("FAILED", "DESTROYED", "ERROR")):
            raise RuntimeError(f"session entered {status}")
        time.sleep(5)
    raise TimeoutError(f"session did not become ready (last status: {last})")


def send_and_collect(session_id: str, text: str) -> str:
    """Send a user message, then read the SSE feed until that run completes.

    Event schema (per API docs): each SSE frame is an `event:` line plus a
    `data:` line with a JSON envelope {type, run_id, data, ...}. Agent text
    streams as run.token_delta {text}; the turn ends with run.completed or
    run.failed. Keepalive comment lines start with ':'.
    """
    # Open the stream first (live attach includes recent context, so no race),
    # then deliver the input.
    chunks, run_id, t0 = [], None, time.time()
    try:
        with httpx.stream("GET", f"{API}/v2/agents/sessions/{session_id}/events",
                          headers=HDRS,
                          timeout=httpx.Timeout(30, read=RUN_TIMEOUT)) as resp:
            r = httpx.post(f"{API}/v2/agents/sessions/{session_id}/input",
                           headers={**HDRS, "Content-Type": "application/json"},
                           json={"text": text}, timeout=30)
            r.raise_for_status()
            run_id = r.json().get("run_id") or None

            for line in resp.iter_lines():
                if time.time() - t0 > RUN_TIMEOUT:
                    break
                if not line or line.startswith(":") or not line.startswith("data:"):
                    continue
                try:
                    ev = json.loads(line[5:].strip())
                except (ValueError, TypeError):
                    continue
                etype = str(ev.get("type", ""))
                ev_run = ev.get("run_id") or ""
                if run_id and ev_run and ev_run != run_id:
                    continue  # event from an earlier run (replayed context)
                data = ev.get("data") or {}
                if etype == "run.token_delta" and isinstance(data.get("text"), str):
                    chunks.append(data["text"])
                elif etype in ("run.completed", "run.failed"):
                    if not run_id or not ev_run or ev_run == run_id:
                        if etype == "run.failed":
                            print(f"    [run failed: {data.get('message', '')}]")
                        break
    except httpx.HTTPError as e:
        print(f"    [events stream ended: {e}]")
    return "".join(chunks).strip()


def destroy(session_id: str):
    try:
        httpx.delete(f"{API}/v2/agents/sessions/{session_id}", headers=HDRS, timeout=30)
    except httpx.HTTPError:
        pass


def run_conversation(config_id: str, persona_name: str, sim: OpenAI, sim_model: str, tag: int):
    p = PERSONAS[persona_name]
    name = f"traffic-{persona_name.replace('_','-')}-{tag}-{random.randint(1000,9999)}"
    session_id = create_session(config_id, name)
    print(f"  session {name} ({session_id})")
    try:
        wait_running(session_id)
        user_msg, transcript = p["opening"], []
        for turn in range(MAX_TURNS):
            print(f"  [customer] {user_msg[:120]}")
            reply = send_and_collect(session_id, user_msg)
            print(f"  [agent]    {(reply or '(no text captured)')[:160]}")
            transcript.append((user_msg, reply))
            sim_messages = [{"role": "system", "content": (
                f"You are role-playing a customer of an online store.\n"
                f"Goal: {p['goal']}\nBehavior: {p['style']}\n"
                "Reply with ONLY the customer's next message. "
                "If the conversation should end, reply with exactly: [END]")}]
            for u, a in transcript:
                sim_messages.append({"role": "assistant", "content": u})
                sim_messages.append({"role": "user", "content": a or "(the agent is still working)"})
            nxt = sim.chat.completions.create(model=sim_model, messages=sim_messages, max_tokens=200)
            user_msg = (nxt.choices[0].message.content or "").strip()
            if "[END]" in user_msg or not user_msg:
                break
    finally:
        destroy(session_id)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list-configs", action="store_true")
    ap.add_argument("--sessions", type=int, default=10)
    ap.add_argument("--persona", default=None)
    ap.add_argument("--mix", default="all")
    args = ap.parse_args()

    if not TOKEN:
        sys.exit("set DIGITALOCEAN_TOKEN")
    if args.list_configs:
        list_configs()
        return

    config_id = os.environ.get("CONFIG_ID") or sys.exit("set CONFIG_ID (try --list-configs)")
    sim = OpenAI(base_url="https://inference.do-ai.run/v1", api_key=os.environ["SIM_KEY"])
    sim_model = os.environ.get("SIM_MODEL", "llama-4-maverick")

    weights = {"happy": 4, "confused": 3, "angry": 3, "quitter": 2, "hasty_refund": 2}
    names = [args.persona] if args.persona else list(weights)
    wts = [weights.get(n, 1) for n in names]

    for i in range(args.sessions):
        persona = args.persona or random.choices(names, weights=wts)[0]
        print(f"\n=== {i+1}/{args.sessions} persona={persona} ===")
        try:
            run_conversation(config_id, persona, sim, sim_model, i)
        except KeyboardInterrupt:
            sys.exit(0)
        except Exception as e:
            print(f"  conversation failed: {e}")


if __name__ == "__main__":
    main()
