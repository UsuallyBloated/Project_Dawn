"""Meshy credit spend gate and secret folder guard: a PreToolUse hook.

For every tool it refuses a call that names the private key folder (see
secret_paths.local.json). For Bash / PowerShell / WebFetch / Write / Edit it
refuses any direct call to Meshy's API host. For mcp__meshy__* tools it
enforces the rules below. Its own balance check calls one host:
api.meshy.ai.

Rule (user, 2026-10-12): Claude may never spend more Meshy credits than the
account holds. This gate enforces it outside the model, so it holds whatever
Claude decides:

  * Free tools (balance, task status, listings, downloads, cancel) pass.
  * Every other Meshy tool is a SPEND. A spend is DENIED unless:
      - the tool has an entry in COST_CEILING (unknown tools are denied), and
      - the live balance, read from Meshy's API at that moment, minus every
        spend this gate approved in the last RESERVE_WINDOW_S seconds, still
        covers the tool's cost ceiling.
  * A spend that passes is never auto-approved: it goes to the user as a
    permission prompt showing the cost ceiling and the balance.
  * Any failure (no key, network error, unreadable reply) DENIES. The hook is
    registered with onFailure "block", so a crash denies too.

Cost ceilings are the HIGHEST price Meshy lists for each operation
(docs.meshy.ai/en/api/pricing, read 2026-10-12, and the MCP server's own price
table, read 2026-10-14), so the check can only err on the side of refusing.
Update them if Meshy's prices change.
"""

import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meshy_key import local_paths, read_key  # noqa: E402

BALANCE_URL = "https://api.meshy.ai/openapi/v1/balance"
HOOK_DIR = os.path.dirname(os.path.abspath(__file__))
LEDGER_PATH = os.path.join(HOOK_DIR, "meshy_spend_ledger.json")
RESERVE_WINDOW_S = 15 * 60

# Our own Meshy client (the user's narrow exception, 2026-10-14): Write and Edit of
# exactly this file may contain Meshy's API address. Nothing else is exempted.
CLIENT_PATH = os.path.join(HOOK_DIR, "meshy_client.py")

# Written by the client when a finished task cost more than expected. While it exists,
# every paid Meshy call is refused. Only the user clears it.
TRIPWIRE_NAME = "meshy_tripwire.json"
TRIPWIRE_PATH = os.path.join(HOOK_DIR, TRIPWIRE_NAME)

FREE_TOOLS = {
    "meshy_check_balance",
    "meshy_get_task_status",
    "meshy_list_tasks",
    "meshy_list_models",
    "meshy_download_model",
    "meshy_cancel_task",
    "meshy_analyze_printability",
    "meshy_list_usage",
    "meshy_list_animations",
}

# Worst-case credits per call, from Meshy's API pricing page.
COST_CEILING = {
    "meshy_text_to_3d": 20,
    "meshy_text_to_3d_refine": 15,
    "meshy_image_to_3d": 40,         # 35 for 8K texture, +5 for Ultra geometry
    "meshy_multi_image_to_3d": 40,   # same
    "meshy_remesh": 5,
    "meshy_retexture": 15,
    "meshy_rig": 5,
    "meshy_animate": 30,             # 3 per action, up to 10 actions
    "meshy_convert": 1,
    "meshy_resize": 1,
    "meshy_uv_unwrap": 5,
    "meshy_text_to_image": 9,
    "meshy_image_to_image": 12,
    "meshy_repair_printability": 10,
    "meshy_process_multicolor": 10,
    "meshy_auto_split": 10,
    "meshy_text_to_motion": 10,      # prime 10, swift 3
    "meshy_creative_lab": 62,        # keycap; most products 36
}


def decide(decision: str, reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def _normalise(text: str) -> str:
    """Lower case, forward slashes, and a Git Bash /x/ drive prefix read as x:/."""
    t = text.lower().replace("\\", "/")
    while "//" in t:
        t = t.replace("//", "/")
    for lead in (" ", "'", '"', "="):
        t = t.replace(lead + "/f/", lead + "f:/")
    return t


def _strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from _strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from _strings(v)


def mentions_secret_folder(tool_input) -> bool:
    """True if any string in the call names a secret folder or the key file.

    Matches the full path, the folder's own name anywhere (so a cd then a
    relative path is caught), and its Windows 8.3 short name. A wildcard
    spelling can still slip past text matching; the CLAUDE.md rule covers that.
    """
    paths = local_paths()
    needles = set()
    for d in paths.get("secret_dirs", []):
        full = _normalise(d).rstrip("/")
        name = full.rsplit("/", 1)[-1]
        needles.update({full, name, name.replace(" ", "")[:6] + "~"})
    key_file = paths.get("meshy_key_file", "")
    if key_file:
        needles.add(_normalise(key_file).rsplit("/", 1)[-1])
    needles.discard("")
    needles.discard("~")
    return any(n in _normalise(" " + s) for s in _strings(tool_input) for n in needles)


def read_balance() -> int:
    key = read_key()
    req = urllib.request.Request(BALANCE_URL, headers={"Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    balance = body["balance"]
    if not isinstance(balance, (int, float)):
        raise RuntimeError(f"balance is not a number: {balance!r}")
    return int(balance)


def load_reservations(now: float) -> list:
    try:
        with open(LEDGER_PATH, encoding="utf-8") as f:
            entries = json.load(f)
    except FileNotFoundError:
        return []
    return [e for e in entries if now - e["t"] < RESERVE_WINDOW_S]


def save_reservations(entries: list) -> None:
    with open(LEDGER_PATH, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=1)


def _same_file(path: str, target: str) -> bool:
    if not path:
        return False
    return os.path.normcase(os.path.abspath(path)) == os.path.normcase(os.path.abspath(target))


def is_client_file_edit(tool: str, tool_input: dict) -> bool:
    """A Write or Edit aimed at exactly our Meshy client file."""
    return tool in ("Write", "Edit") and _same_file(tool_input.get("file_path", ""), CLIENT_PATH)


def touches_tripwire(tool: str, tool_input: dict) -> bool:
    """A shell command naming the tripwire, or a file tool aimed at it."""
    if tool in ("Bash", "PowerShell"):
        return TRIPWIRE_NAME in str(tool_input.get("command", "")).lower()
    path = tool_input.get("file_path", "") or tool_input.get("notebook_path", "")
    return tool in ("Write", "Edit", "NotebookEdit") and _same_file(path, TRIPWIRE_PATH)


# Names that reach the key or the client from outside a Meshy tool call. A shell
# command may not name them, and no file may gain them except the ones that own them.
KEY_ACCESS_NAMES = ("meshy_key", "read_key", "meshy_client", "meshy_mcp_launch", "secret_paths")
KEY_ACCESS_OWNERS = ("meshy_key.py", "meshy_client.py", "meshy_spend_gate.py")


def reaches_key_outside_tools(tool: str, tool_input: dict) -> bool:
    """A shell command or a new file that could use the key without the gate seeing it."""
    if tool in ("Bash", "PowerShell"):
        command = str(tool_input.get("command", "")).lower()
        return any(name in command for name in KEY_ACCESS_NAMES)
    if tool in ("Write", "Edit", "NotebookEdit"):
        path = tool_input.get("file_path", "") or tool_input.get("notebook_path", "")
        if any(_same_file(path, os.path.join(HOOK_DIR, owner)) for owner in KEY_ACCESS_OWNERS):
            return False
        new_text = " ".join(str(tool_input.get(k, "")) for k in ("content", "new_string", "new_source"))
        return any(name in new_text.lower() for name in ("meshy_key", "read_key"))
    return False


def main() -> None:
    payload = json.load(sys.stdin)
    tool = payload.get("tool_name", "")

    # The private key folder: no tool call may name it, whatever the tool.
    # The launcher and this gate read the key themselves, outside any tool call.
    if mentions_secret_folder(payload.get("tool_input", {})):
        decide("deny", "Secret folder guard: this call names the private key folder or the key file. "
                       "Claude never reads, lists, copies or commits anything there (CLAUDE.md).")

    tool_input = payload.get("tool_input", {})

    # The key and the client are reached only through Meshy tool calls, which this
    # gate sees. Running them from a shell would skip the gate and the user's prompt.
    if reaches_key_outside_tools(tool, tool_input):
        decide("deny", "Key access guard: the Meshy key and client are used only through the Meshy "
                       "tools, never from a shell command or a new script (CLAUDE.md).")

    # The price tripwire is the user's to clear, never Claude's.
    if touches_tripwire(tool, tool_input):
        decide("deny", "Meshy price tripwire: only the user may inspect, change or clear it.")

    # The one exception: our own Meshy client file may contain the API address.
    if is_client_file_edit(tool, tool_input):
        sys.exit(0)

    # Shell and fetch tools: refuse anything that talks to Meshy's API directly,
    # since that would spend credits without passing through this gate.
    if not tool.startswith("mcp__meshy__"):
        if "api.meshy.ai" in json.dumps(payload.get("tool_input", {})).lower():
            decide("deny", "Meshy spend gate: direct calls to api.meshy.ai are not allowed. "
                           "Use the Meshy MCP tools, which pass through the credit check.")
        sys.exit(0)

    short = tool.split("__")[-1]

    if short in FREE_TOOLS:
        sys.exit(0)

    if short not in COST_CEILING:
        decide("deny", f"Meshy spend gate: '{short}' has no cost ceiling on file, so it is refused. "
                       "Add it to COST_CEILING in .claude/hooks/meshy_spend_gate.py after checking Meshy's pricing.")

    if os.path.exists(TRIPWIRE_PATH):
        decide("deny", "Meshy price tripwire is set: a finished task cost more than expected. "
                       "Every paid call is refused until the user has reviewed it and cleared the tripwire.")

    cost = COST_CEILING[short]
    try:
        balance = read_balance()
    except Exception as exc:
        decide("deny", f"Meshy spend gate: could not read the live balance ({exc}). Refusing to spend.")

    now = time.time()
    reservations = load_reservations(now)
    reserved = sum(e["cost"] for e in reservations)
    available = balance - reserved

    if cost > available:
        decide("deny", f"Meshy spend gate: {short} can cost up to {cost} credits but only {available} are "
                       f"available (balance {balance}, {reserved} reserved by recent calls). Refused.")

    reservations.append({"t": now, "tool": short, "cost": cost})
    save_reservations(reservations)
    decide("ask", f"Meshy spend: {short} costs up to {cost} credits. Balance {balance}, "
                  f"{reserved} reserved by recent calls, {available - cost} left after this. Approve?")


if __name__ == "__main__":
    main()
