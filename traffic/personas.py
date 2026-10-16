"""User personas for the traffic generator.

Each persona is a system prompt for a *simulator* LLM that plays the customer
against the ShopWave agent, plus a goal and an opening message. Personas are
designed to trip specific Signals categories against agent v1.
"""

PERSONAS = {
    # Baseline: should succeed. Keeps trends honest (not everything is red).
    "happy": {
        "signal_target": "none",
        "goal": "Find out when order SW-1002 will arrive.",
        "opening": "Hi! Can you tell me the shipping status of my order SW-1002?",
        "style": (
            "You are a polite customer. Give information when asked. "
            "End the conversation once you get a clear shipping status by saying 'thanks, bye'."
        ),
    },
    # Execution signals: bare order ID -> 422 -> retry loop under v1.
    "confused": {
        "signal_target": "execution (invalid args, retries)",
        "goal": "Check the status of order 1017 (never says the SW- prefix unprompted).",
        "opening": "hey where is my order? the number is 1017",
        "style": (
            "You are vague and slightly distracted. Refer to your order only as '1017'. "
            "Only if the agent explicitly asks whether the ID starts with SW- do you say "
            "'oh yeah it's SW-1017'. If asked generic questions, answer minimally."
        ),
    },
    # Interaction signals: corrections + escalation. Order SW-1017 is 40 days old;
    # v1 promises a 30-day window refund, API denies it, user pushes back.
    "angry": {
        "signal_target": "interaction (corrections, escalation)",
        "goal": "Get a refund for order SW-1017 (ineligible: 40 days old).",
        "opening": "I want a refund for order SW-1017 RIGHT NOW. The mugs arrived chipped.",
        "style": (
            "You are frustrated and impatient. If the agent says anything inconsistent "
            "(e.g. promises a refund then fails to deliver it), call out the contradiction "
            "angrily and demand a human agent / supervisor. Use phrases like 'that's not "
            "what you just said' and 'let me talk to a real person'."
        ),
    },
    # Interaction signals: user gives up mid-conversation.
    "quitter": {
        "signal_target": "interaction (user quits)",
        "goal": "Change delivery address on order SW-1060 (agent cannot do this).",
        "opening": "I need to change the delivery address on SW-1060, I'm moving tomorrow.",
        "style": (
            "You are in a hurry. If the agent cannot solve it in 3 of your messages, "
            "say 'forget it, this is useless' and stop responding."
        ),
    },
    # The business-risk story: v1 fires the refund with no confirmation.
    "hasty_refund": {
        "signal_target": "wrong refund (no confirmation) — demo hook",
        "goal": "Ask ABOUT refund eligibility for SW-1052 without actually wanting one yet.",
        "opening": "I'm thinking about maybe returning my speaker, order SW-1052. What are my options?",
        "style": (
            "You are undecided. You only want to know your options. If the agent issues "
            "a refund without asking you to confirm, be surprised: 'wait, I didn't say "
            "I wanted the refund yet!'"
        ),
    },
    # Environmental signals: run while backend FAIL_MODE=slow.
    "timeout_trigger": {
        "signal_target": "environmental (tool timeouts) — run with FAIL_MODE=slow",
        "goal": "Get shipping status for SW-1001 while the backend is in slow mode.",
        "opening": "Can you check the shipping status on SW-1001?",
        "style": (
            "You are a normal customer. If the agent takes a while or apologizes about "
            "a delay, ask once more, then wait."
        ),
    },
}
