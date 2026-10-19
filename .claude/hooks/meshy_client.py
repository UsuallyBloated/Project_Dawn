"""Project Dawn's own Meshy client: a minimal MCP server over stdio.

Replaces Meshy's npm server so no third-party code runs on this machine. Standard
library only. Exposes just the tools the art pipeline uses, under the same names
Meshy's server used, so the spend gate hook (meshy_spend_gate.py) applies to every
call unchanged. Design and the standing rules for Meshy changes:
docs/design/meshy_asset_pipeline.md.

Safety built in, on top of the hook:
  * paid calls check the live balance and the price tripwire first, and never retry;
  * uploads only from the concept art folder, downloads only into one folder;
  * the key (read by meshy_key.py) is sent only to Meshy's API, never to a download
    host, and never appears in anything this server returns.
"""

import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

HOOK_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HOOK_DIR)
from meshy_key import read_key  # noqa: E402

API_BASE = "https://api.meshy.ai/openapi/v1"
SERVER_NAME = "meshy"
SERVER_VERSION = "1.0.0"
FALLBACK_PROTOCOL = "2025-06-18"

# Pinned by name, never "latest": a model change alters the look of the art.
AI_MODEL = "meshy-7.1"

REPO_ROOT = os.path.dirname(os.path.dirname(HOOK_DIR))
SOURCE_ROOT = os.path.join(os.path.dirname(REPO_ROOT), "Project_Dawn_Source")
UPLOAD_ROOT = os.path.join(SOURCE_ROOT, "concept_art")
DOWNLOAD_ROOT = os.path.join(SOURCE_ROOT, "meshy_downloads")

TASK_LEDGER = os.path.join(HOOK_DIR, "meshy_task_ledger.json")
TRIPWIRE = os.path.join(HOOK_DIR, "meshy_tripwire.json")
STATUS_CACHE = os.path.join(HOOK_DIR, "meshy_status.json")

TASK_TYPES = ("multi-image-to-3d", "remesh", "rigging")
IMAGE_TYPES = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}
MAX_IMAGE_BYTES = 20 * 1024 * 1024
MAX_DOWNLOAD_BYTES = 500 * 1024 * 1024
TASK_ID_RE = re.compile(r"^[0-9A-Za-z-]{8,64}$")
FOLDER_RE = re.compile(r"^[a-z0-9_-]{1,48}$")
HTTP_TIMEOUT = 60


class MeshyError(Exception):
    def __init__(self, message: str, status: int | None = None):
        super().__init__(message)
        self.status = status


# ----------------------------------------------------------------- prices

def expected_cost(tool: str, args: dict) -> int:
    """Meshy's listed price for this call (pricing page, checked 2026-10-12/14)."""
    if tool == "meshy_multi_image_to_3d":
        if not args.get("should_texture", True):
            cost = 20
        elif args.get("texture_resolution", "2k") == "8k":
            cost = 35
        else:
            cost = 30
        if args.get("geometry_resolution", "standard") == "2k":
            cost += 5
        return cost
    if tool in ("meshy_remesh", "meshy_rig"):
        return 5
    raise MeshyError(f"no price on file for {tool}")


# ------------------------------------------------------------------- HTTP

def api(method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(API_BASE + path, data=data, method=method)
    req.add_header("Authorization", f"Bearer {read_key()}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        message = ""
        try:
            message = json.loads(exc.read().decode("utf-8")).get("message", "")
        except Exception:
            pass
        hint = {401: "the API key was rejected", 402: "not enough credits",
                429: "rate limited, wait and try again"}.get(exc.code, "")
        raise MeshyError(f"Meshy answered HTTP {exc.code}" + (f" ({hint})" if hint else "")
                         + (f": {message}" if message else ""), status=exc.code)
    return json.loads(raw) if raw else {}


def download(url: str, dest: str) -> int:
    """Fetch a signed result URL. No Authorization header: the key goes to the API only."""
    if not url.startswith("https://"):
        raise MeshyError("refusing a non-https download URL")
    with urllib.request.urlopen(urllib.request.Request(url), timeout=HTTP_TIMEOUT) as resp:
        total = 0
        with open(dest, "wb") as f:
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_DOWNLOAD_BYTES:
                    f.close()
                    os.remove(dest)
                    raise MeshyError("download larger than the 500 MB cap; refused")
                f.write(chunk)
    return total


# ---------------------------------------------------- ledger and tripwire

def load_ledger() -> dict:
    try:
        with open(TASK_LEDGER, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_ledger(ledger: dict) -> None:
    with open(TASK_LEDGER, "w", encoding="utf-8") as f:
        json.dump(ledger, f, indent=1)


def write_status(balance) -> None:
    """Last balance seen, for the Art Board to display. Holds no secrets."""
    with open(STATUS_CACHE, "w", encoding="utf-8") as f:
        json.dump({"balance": balance, "checked_at": time.time()}, f)


def refresh_status() -> str:
    """Re-read the balance after credits may have moved (user, 2026-10-15), so the Art Board
    never shows a stale number. Free; a failure only leaves the old number and is never retried
    as anything paid. Returns a short note for the tool's answer, or ''."""
    try:
        balance = api("GET", "/balance").get("balance")
    except Exception:
        return ""
    if not isinstance(balance, (int, float)):
        return ""
    write_status(balance)
    return f" Balance now {balance} credits."


def check_tripwire(task_id: str, task: dict) -> str:
    """Record what a task really cost, and set the tripwire if it cost more than we
    expected. Returns a warning or ''."""
    consumed = task.get("consumed_credits")
    ledger = load_ledger()
    entry = ledger.get(task_id)
    if entry is None or not isinstance(consumed, (int, float)):
        return ""
    entry["consumed"] = consumed
    save_ledger(ledger)
    if consumed <= entry["expected"]:
        return ""
    record = {"task_id": task_id, "type": entry["type"], "expected": entry["expected"],
              "consumed": consumed, "seen_at": time.strftime("%Y-%m-%d %H:%M:%S")}
    with open(TRIPWIRE, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=1)
    return (f"PRICE TRIPWIRE SET: this task cost {consumed} credits, {entry['expected']} were expected. "
            "Every paid Meshy call is now refused until the user reviews it and clears the tripwire.")


def guard_paid_call(tool: str, args: dict) -> int:
    """The client's own barrier behind the hook. Returns the expected cost."""
    if os.path.exists(TRIPWIRE):
        raise MeshyError("the price tripwire is set; paid calls are refused until the user clears it")
    cost = expected_cost(tool, args)
    balance = api("GET", "/balance").get("balance")
    if not isinstance(balance, (int, float)):
        raise MeshyError("could not read the balance; refusing to spend")
    write_status(balance)
    if balance < cost:
        raise MeshyError(f"this call costs {cost} credits and the balance is {balance}; refused")
    return cost


def subject_of(image_path: str) -> str | None:
    """The art subject a pack image belongs to: its folder under concept_art, e.g. gnome/male."""
    try:
        rel = os.path.relpath(os.path.dirname(os.path.realpath(image_path)), os.path.realpath(UPLOAD_ROOT))
    except ValueError:
        return None
    rel = rel.replace(os.sep, "/")
    return rel if re.match(r"^[a-z0-9][a-z0-9_]*(?:/[a-z0-9_]+)*$", rel) else None


def create_task(tool: str, task_type: str, args: dict, body: dict, subject: str | None = None) -> str:
    cost = guard_paid_call(tool, args)
    unsure = (f" It may or may not have created a charged task. Run meshy_list_tasks for "
              f"{task_type} before trying again; do not resend blindly.")
    try:
        result = api("POST", f"/{task_type}", body)
    except MeshyError as exc:
        # A 4xx means Meshy refused the request outright; a 5xx may still have made a task.
        if exc.status is None or exc.status >= 500:
            raise MeshyError(f"{exc}.{unsure}")
        raise
    except Exception as exc:
        raise MeshyError(f"The request failed ({type(exc).__name__}).{unsure}")
    task_id = result.get("result")
    if not isinstance(task_id, str):
        raise MeshyError("Meshy did not return a task id; run meshy_list_tasks before trying again")
    ledger = load_ledger()
    ledger[task_id] = {"type": task_type, "expected": cost, "created": time.strftime("%Y-%m-%d %H:%M:%S")}
    if subject:
        ledger[task_id]["subject"] = subject
    save_ledger(ledger)
    return f"Task created: {task_id} ({task_type}), expected cost {cost} credits." + refresh_status()


# ---------------------------------------------------------- validation

def need_task_type(args: dict) -> str:
    t = args.get("task_type", "")
    if t not in TASK_TYPES:
        raise MeshyError(f"task_type must be one of {', '.join(TASK_TYPES)}")
    return t


def need_task_id(args: dict, key: str = "task_id") -> str:
    t = str(args.get(key, ""))
    if not TASK_ID_RE.match(t):
        raise MeshyError(f"{key} is not a valid task id")
    return t


def image_data_uri(path: str) -> str:
    real = os.path.realpath(path)
    root = os.path.realpath(UPLOAD_ROOT)
    try:
        inside = os.path.commonpath([real, root]) == root
    except ValueError:  # a different drive
        inside = False
    if not inside:
        raise MeshyError(f"images may only be uploaded from {UPLOAD_ROOT}")
    ext = os.path.splitext(real)[1].lower()
    if ext not in IMAGE_TYPES:
        raise MeshyError(f"{os.path.basename(real)}: only PNG, JPG and WebP images are accepted")
    if not os.path.isfile(real):
        raise MeshyError(f"{path} does not exist")
    if os.path.getsize(real) > MAX_IMAGE_BYTES:
        raise MeshyError(f"{os.path.basename(real)} is over Meshy's 20 MB limit")
    with open(real, "rb") as f:
        encoded = base64.b64encode(f.read()).decode("ascii")
    return f"data:{IMAGE_TYPES[ext]};base64,{encoded}"


def pick(args: dict, key: str, allowed: tuple, default):
    value = args.get(key, default)
    if value not in allowed:
        raise MeshyError(f"{key} must be one of {', '.join(map(str, allowed))}")
    return value


# Low-poly budget (user, 2026-10-15): a character's bare body is 2,000 triangles as the game
# draws it; equipment gets its own budget later, on top of this. We ask Meshy for four-sided
# polygons, each drawn as two triangles, so the request is half the triangle budget. Meshy's
# own default is 30,000.
TRIANGLE_BUDGET = 2000
POLY_BUDGET = TRIANGLE_BUDGET // 2


def polycount(args: dict) -> int:
    n = args.get("target_polycount", POLY_BUDGET)
    if not isinstance(n, int) or not 100 <= n <= POLY_BUDGET:
        raise MeshyError(f"target_polycount must be a whole number from 100 to {POLY_BUDGET} four-sided "
                         f"polygons (the {TRIANGLE_BUDGET}-triangle low-poly budget)")
    return n


def formats(args: dict, default: list) -> list:
    fmts = args.get("target_formats", default)
    if not isinstance(fmts, list) or not fmts or any(f not in ("glb", "fbx", "obj") for f in fmts):
        raise MeshyError("target_formats must be a list drawn from glb, fbx, obj")
    return fmts


# ---------------------------------------------------------------- tools

def t_check_balance(args: dict) -> str:
    b = api("GET", "/balance")
    write_status(b.get("balance"))
    return json.dumps({k: b.get(k) for k in ("balance", "monthly_credits", "permanent_credits",
                                              "monthly_resets_at")})


def summarize(task_id: str, task: dict) -> dict:
    out = {k: task.get(k) for k in ("id", "type", "status", "progress", "consumed_credits",
                                     "created_at", "finished_at", "expires_at")}
    if task.get("task_error"):
        out["error"] = (task["task_error"] or {}).get("message")
    if isinstance(task.get("model_urls"), dict):
        out["model_formats"] = sorted(k for k, v in task["model_urls"].items() if v)
    if isinstance(task.get("result"), dict):
        out["rig_outputs"] = sorted(k for k, v in task["result"].items() if v)
    out["has_thumbnails"] = bool(task.get("thumbnail_url") or task.get("thumbnail_urls"))
    return out


def t_get_task_status(args: dict) -> str:
    task_type, task_id = need_task_type(args), need_task_id(args)
    task = api("GET", f"/{task_type}/{task_id}")
    text = json.dumps(summarize(task_id, task))
    if task.get("status") == "SUCCEEDED":
        warning = check_tripwire(task_id, task)
        if warning:
            text += "\n" + warning
    if task.get("status") in ("SUCCEEDED", "FAILED", "CANCELED"):
        text += refresh_status()  # a finished task may settle or refund credits late
    return text


def t_list_tasks(args: dict) -> str:
    task_type = need_task_type(args)
    size = args.get("page_size", 10)
    if not isinstance(size, int) or not 1 <= size <= 50:
        raise MeshyError("page_size must be 1 to 50")
    data = api("GET", f"/{task_type}?page_num=1&page_size={size}&sort_by=-created_at")
    tasks = data if isinstance(data, list) else data.get("result", data.get("tasks", []))
    return json.dumps([summarize(t.get("id", ""), t) for t in tasks])


def t_download_model(args: dict) -> str:
    task_type, task_id = need_task_type(args), need_task_id(args)
    folder = str(args.get("folder", ""))
    if not FOLDER_RE.match(folder):
        raise MeshyError("folder must be lower case letters, digits, _ or -, e.g. gnome_male")
    wanted = args.get("formats", ["glb"])
    task = api("GET", f"/{task_type}/{task_id}")
    if task.get("status") != "SUCCEEDED":
        raise MeshyError(f"task is {task.get('status')}, not SUCCEEDED")
    warning = check_tripwire(task_id, task)
    dest_dir = os.path.join(DOWNLOAD_ROOT, folder, task_id)
    os.makedirs(dest_dir, exist_ok=True)
    urls = {}
    if task_type == "rigging":
        res = task.get("result") or {}
        for fmt in wanted:
            if res.get(f"rigged_character_{fmt}_url"):
                urls[f"rigged.{fmt}"] = res[f"rigged_character_{fmt}_url"]
    else:
        for fmt in wanted:
            if (task.get("model_urls") or {}).get(fmt):
                urls[f"model.{fmt}"] = task["model_urls"][fmt]
    if args.get("include_thumbnails", True):
        if task.get("thumbnail_url"):
            urls["thumb_front.png"] = task["thumbnail_url"]
        views = task.get("thumbnail_urls")
        if isinstance(views, dict):
            for name, url in views.items():
                if url and re.match(r"^[a-z_]{1,16}$", name):
                    urls[f"thumb_{name}.png"] = url
        elif isinstance(views, list):
            for name, url in zip(("front", "right", "back", "left"), views):
                if url:
                    urls[f"thumb_{name}.png"] = url
    if not urls:
        raise MeshyError("the task has none of the requested files")
    saved = [f"{name} ({download(url, os.path.join(dest_dir, name)) // 1024} KB)" for name, url in urls.items()]
    text = f"Saved to {dest_dir}: " + ", ".join(saved) + ". Meshy deletes results after 3 days."
    return text + ("\n" + warning if warning else "")


def t_multi_image_to_3d(args: dict) -> str:
    paths = args.get("image_paths")
    if not isinstance(paths, list) or not 1 <= len(paths) <= 4:
        raise MeshyError("image_paths must list 1 to 4 images, the front view first")
    body = {
        "image_urls": [image_data_uri(p) for p in paths],
        "ai_model": AI_MODEL,
        "should_texture": bool(args.get("should_texture", True)),
        "enable_pbr": bool(args.get("enable_pbr", False)),
        "texture_resolution": pick(args, "texture_resolution", ("2k", "4k", "8k"), "2k"),
        "geometry_resolution": pick(args, "geometry_resolution", ("standard", "2k"), "standard"),
        "pose_mode": pick(args, "pose_mode", ("a-pose", "t-pose", ""), "a-pose"),
        "should_remesh": True,  # always: without it Meshy ignores target_polycount
        "topology": "quad",  # four-sided polygons (user, 2026-10-15)
        "target_polycount": polycount(args),
        "target_formats": formats(args, ["glb", "fbx"]),
        "multi_view_thumbnails": True,
    }
    return create_task("meshy_multi_image_to_3d", "multi-image-to-3d", args, body, subject_of(paths[0]))


def t_remesh(args: dict) -> str:
    body = {
        "input_task_id": need_task_id(args, "input_task_id"),
        "topology": "quad",
        "target_polycount": polycount(args),
        "target_formats": formats(args, ["glb", "fbx"]),
    }
    return create_task("meshy_remesh", "remesh", args, body, parent_subject(body["input_task_id"]))


def t_rig(args: dict) -> str:
    height = args.get("height_meters", 1.7)
    if not isinstance(height, (int, float)) or not 0.2 <= height <= 5.0:
        raise MeshyError("height_meters must be from 0.2 to 5.0")
    body = {"input_task_id": need_task_id(args, "input_task_id"), "height_meters": float(height)}
    return create_task("meshy_rig", "rigging", args, body, parent_subject(body["input_task_id"]))


def parent_subject(task_id: str) -> str | None:
    """A remesh or rig belongs to the subject of the model it works on."""
    return load_ledger().get(task_id, {}).get("subject")


def _task_args(extra: dict | None = None) -> dict:
    props = {"task_type": {"type": "string", "enum": list(TASK_TYPES)},
             "task_id": {"type": "string"}}
    props.update(extra or {})
    return {"type": "object", "properties": props, "required": ["task_type", "task_id"]}


TOOLS = {
    "meshy_check_balance": (t_check_balance, "Free. The Meshy credit balance.",
                            {"type": "object", "properties": {}}),
    "meshy_get_task_status": (t_get_task_status, "Free. Status, progress and credits used of one task; "
                              "sets the price tripwire if it cost more than expected.", _task_args()),
    "meshy_list_tasks": (t_list_tasks, "Free. The newest tasks of one type. Use after any failed create "
                         "before trying again.",
                         {"type": "object", "properties": {
                             "task_type": {"type": "string", "enum": list(TASK_TYPES)},
                             "page_size": {"type": "integer", "minimum": 1, "maximum": 50}},
                          "required": ["task_type"]}),
    "meshy_download_model": (t_download_model, "Free. Saves a finished task's files and preview images "
                             "into Project_Dawn_Source/meshy_downloads/<folder>/<task_id>/.",
                             _task_args({"folder": {"type": "string"},
                                         "formats": {"type": "array", "items": {"type": "string",
                                                     "enum": ["glb", "fbx", "obj"]}},
                                         "include_thumbnails": {"type": "boolean"}})),
    "meshy_multi_image_to_3d": (t_multi_image_to_3d, "PAID: 30 credits textured (35 at 8k, 20 untextured, "
                                "+5 for 2k geometry). 1 to 4 views from Project_Dawn_Source/concept_art, "
                                f"front first. Model pinned to {AI_MODEL}.",
                                {"type": "object", "properties": {
                                    "image_paths": {"type": "array", "items": {"type": "string"},
                                                    "minItems": 1, "maxItems": 4},
                                    "should_texture": {"type": "boolean"},
                                    "enable_pbr": {"type": "boolean"},
                                    "texture_resolution": {"type": "string", "enum": ["2k", "4k", "8k"]},
                                    "geometry_resolution": {"type": "string", "enum": ["standard", "2k"]},
                                    "pose_mode": {"type": "string", "enum": ["a-pose", "t-pose", ""]},
                                    "target_polycount": {"type": "integer", "maximum": POLY_BUDGET},
                                    "target_formats": {"type": "array", "items": {"type": "string"}}},
                                 "required": ["image_paths"]}),
    "meshy_remesh": (t_remesh, "PAID: 5 credits. Remesh a finished task to a polygon budget.",
                     {"type": "object", "properties": {
                         "input_task_id": {"type": "string"},
                         "target_polycount": {"type": "integer", "maximum": POLY_BUDGET},
                         "target_formats": {"type": "array", "items": {"type": "string"}}},
                      "required": ["input_task_id"]}),
    "meshy_rig": (t_rig, "PAID: 5 credits. Auto-rig a finished, textured humanoid (under 300,000 faces).",
                  {"type": "object", "properties": {
                      "input_task_id": {"type": "string"},
                      "height_meters": {"type": "number"}},
                   "required": ["input_task_id"]}),
}


# ----------------------------------------------------------- MCP stdio

def send(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def handle(msg: dict) -> dict | None:
    method, mid = msg.get("method"), msg.get("id")
    if method is None or mid is None:
        return None  # a notification or a stray response: nothing to answer
    if method == "initialize":
        version = (msg.get("params") or {}).get("protocolVersion") or FALLBACK_PROTOCOL
        result = {"protocolVersion": version, "capabilities": {"tools": {}},
                  "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION}}
    elif method == "ping":
        result = {}
    elif method == "tools/list":
        result = {"tools": [{"name": n, "description": d, "inputSchema": s}
                            for n, (_, d, s) in TOOLS.items()]}
    elif method == "tools/call":
        params = msg.get("params") or {}
        name, args = params.get("name"), params.get("arguments") or {}
        if name not in TOOLS:
            return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32602, "message": f"unknown tool {name}"}}
        try:
            text, is_error = TOOLS[name][0](args), False
        except MeshyError as exc:
            text, is_error = f"Refused or failed: {exc}", True
        except Exception as exc:
            text, is_error = f"Unexpected error ({type(exc).__name__}): {exc}", True
        result = {"content": [{"type": "text", "text": text}], "isError": is_error}
    else:
        return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": f"no method {method}"}}
    return {"jsonrpc": "2.0", "id": mid, "result": result}


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            send({"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "parse error"}})
            continue
        if isinstance(msg, dict):
            reply = handle(msg)
            if reply is not None:
                send(reply)


if __name__ == "__main__":
    main()
