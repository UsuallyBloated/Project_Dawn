"""Project Dawn Art Board: a local page tracking the character-model workflow.

Run `python tools/art_board/art_board.py` (or double-click open_art_board.bat) and it
opens in your browser. Add `--demo` to try the buttons against a throwaway copy of the
approvals and the checklist (the model files are only read). It shows:
  * a card per playable race with a male and a female line, walking the hand-built
    workflow in docs/design/character_model_workflow.md: model pack, body built in
    Blender, exported, UV unwrap, texture, rig, in game. Each step is detected from the
    files (race_progress.py), then approved here; approving "in game" ticks the race's
    row in docs/design/art_assets_checklist.md (the ONE art list; this page reads it and
    never keeps a second copy),
  * a lineup of the exported models rendered and drawn at their measured heights,
  * progress for every section of the art checklist,
  * model sheets made with Meshy's 2D tools (sheets.py): each candidate on its race's card,
    or under "Other sheets" for anything that is not a race, with the prompt, model and
    reference images that made it; "Use this" puts it in ref_art as the ModelPack sheet,
  * the shelved Meshy loop, kept whole: credits as last seen by the Meshy client, credits
    spent, the price tripwire, the style bible and the concept-art cards (pack images,
    prompts, Claude's review, Meshy's previews, Approve / Re-roll / Sign off).

It never calls Meshy and never touches the API key: a button only records your decision
(progress.json for the races, review.json for the concept-art cards, sheets.json for the
generated sheets), ticks checklist rows, and copies a sheet you chose into ref_art. Standard library only; listens on 127.0.0.1 alone, and every change needs the page's
own random token, so no other website can click the buttons for you.
"""

import html
import json
import math
import mimetypes
import os
import re
import secrets
import shutil
import struct
import sys
import tempfile
import time
import webbrowser
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import race_progress
import sheets

BOARD_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(BOARD_DIR))
CHECKLIST = os.path.join(REPO_ROOT, "docs", "design", "art_assets_checklist.md")
HOOK_DIR = os.path.join(REPO_ROOT, ".claude", "hooks")
STATUS_CACHE = os.path.join(HOOK_DIR, "meshy_status.json")
TRIPWIRE = os.path.join(HOOK_DIR, "meshy_tripwire.json")
TASK_LEDGER = os.path.join(HOOK_DIR, "meshy_task_ledger.json")
SOURCE_ROOT = os.path.join(os.path.dirname(REPO_ROOT), "Project_Dawn_Source")
CONCEPT_ROOT = os.path.join(SOURCE_ROOT, "concept_art")
DOWNLOAD_ROOT = os.path.join(SOURCE_ROOT, "meshy_downloads")
DISCARD_ROOT = os.path.join(SOURCE_ROOT, "discarded")  # one folder per race (user, 2026-10-23)
STYLE_DIR = os.path.join(CONCEPT_ROOT, "_style_bible")
DEMO = False

PORTS = range(8790, 8800)
DEMO_PORTS = range(8800, 8810)
TOKEN = secrets.token_urlsafe(24)
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp"}
PROMPT_TOOLS = ("Gemini", "Grok", "Other")
HEIGHT_TOLERANCE = 0.02  # a measured height may sit 2% outside the race's range
SUBJECT_RE = re.compile(r"^[a-z0-9_]+(?:/[a-z0-9_]+)*$")
ITEM_RE = re.compile(r"^- \[( |x|X)\] (.*)$")
ITEM_SUBJECT_RE = re.compile(r"\(`([a-z0-9_]+(?:/[a-z0-9_]+)*)`\)\s*$")
SECTION_RE = re.compile(r"^## (\d+)\. (.*)$")
STEP_NAMES = ["Style bible", "Pack made", "Claude reviews", "You approve pack",
              "Meshy 3D", "In game", "Done"]


# --------------------------------------------------------------- checklist

def read_checklist() -> list:
    """Sections of the art checklist with their rows, in file order."""
    sections, current, group = [], None, ""
    with open(CHECKLIST, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            m = SECTION_RE.match(line)
            if m:
                title = re.split(r"\s+[—-]\s+`", m.group(2))[0].strip()
                current = {"num": int(m.group(1)), "title": title, "items": []}
                sections.append(current)
                group = ""
                continue
            if line.startswith("## "):
                current = None
                continue
            if current is None:
                continue
            if line.startswith("### "):
                group = line[4:].strip()
                continue
            m = ITEM_RE.match(line)
            if m:
                text = m.group(2).strip()
                sm = ITEM_SUBJECT_RE.search(text)
                current["items"].append({
                    "text": ITEM_SUBJECT_RE.sub("", text).strip(),
                    "done": m.group(1).lower() == "x",
                    "group": group,
                    "subject": sm.group(1) if sm else None,
                })
    for s in sections:
        s["done"] = sum(1 for i in s["items"] if i["done"])
        s["total"] = len(s["items"])
    return [s for s in sections if s["total"]]


def tick_checklist(subject: str, done: bool = True) -> bool:
    """Tick (or untick) the checklist row carrying (`subject`). False when there is nothing to change."""
    old, new = ("- [ ]", "- [x]") if done else ("- [x]", "- [ ]")
    with open(CHECKLIST, encoding="utf-8", newline="") as f:
        lines = f.readlines()
    for i, line in enumerate(lines):
        m = ITEM_RE.match(line.rstrip("\r\n"))
        sm = ITEM_SUBJECT_RE.search(m.group(2)) if m else None
        if m and sm and sm.group(1) == subject and (m.group(1) == " ") == done:
            lines[i] = line.replace(old, new, 1) if done else re.sub(r"- \[[xX]\]", "- [ ]", line, count=1)
            with open(CHECKLIST, "w", encoding="utf-8", newline="") as f:
                f.writelines(lines)
            return True
    return False


# ----------------------------------------------------------------- heights

race_id = race_progress.race_id  # one home for the race-name rule


def read_heights() -> dict:
    """Race id to (low, high) metres, from the playable-race table of creature_heights.md."""
    return {rid: (lo, hi) for rid, _name, lo, hi in race_progress.read_races()}


# ------------------------------------------------------------------- spend

def read_ledger() -> dict:
    try:
        with open(TASK_LEDGER, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def spend_by_subject(ledger: dict) -> tuple:
    """Credits per subject from the Meshy client's task ledger, and the total."""
    per, total = {}, 0
    for entry in ledger.values():
        credits = entry.get("consumed", entry.get("expected", 0)) or 0
        total += credits
        sid = entry.get("subject")
        if sid:
            s = per.setdefault(sid, {"credits": 0, "estimated": False, "tasks": 0})
            s["credits"] += credits
            s["tasks"] += 1
            s["estimated"] = s["estimated"] or "consumed" not in entry
    return per, total


# ---------------------------------------------------------------- subjects

def subject_dir(sid: str) -> str:
    return os.path.join(CONCEPT_ROOT, *sid.split("/"))


def load_review(sid: str) -> dict:
    try:
        with open(os.path.join(subject_dir(sid), "review.json"), encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_json(path: str, data: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, path)


def save_review(sid: str, data: dict) -> None:
    save_json(os.path.join(subject_dir(sid), "review.json"), data)


def images_in(folder: str) -> list:
    if not os.path.isdir(folder):
        return []
    return sorted(n for n in os.listdir(folder)
                  if os.path.splitext(n)[1].lower() in IMAGE_EXT and os.path.isfile(os.path.join(folder, n)))


def front_image(names: list) -> str | None:
    for n in names:
        if "front" in n.lower():
            return n
    return names[0] if names else None


def discover_subjects(checklist: list) -> dict:
    """Every subject named in the checklist, plus any concept_art folder with images."""
    names = {}
    for s in checklist:
        for item in s["items"]:
            if item["subject"]:
                names[item["subject"]] = {"title": item["text"], "ticked": item["done"]}
    if os.path.isdir(CONCEPT_ROOT):
        for root, dirs, files in os.walk(CONCEPT_ROOT):
            dirs[:] = [d for d in dirs if not d.startswith("_")]
            if any(os.path.splitext(f)[1].lower() in IMAGE_EXT for f in files) or "review.json" in files:
                sid = os.path.relpath(root, CONCEPT_ROOT).replace(os.sep, "/")
                if SUBJECT_RE.match(sid):
                    names.setdefault(sid, {"title": sid, "ticked": False})
    return names


def subject_state(sid: str, title: str, ticked: bool, heights: dict | None = None,
                  spend: dict | None = None) -> dict:
    folder = subject_dir(sid)
    images = images_in(folder)
    review = load_review(sid)
    newest = max((os.path.getmtime(os.path.join(folder, n)) for n in images), default=0)
    rv = review.get("review") or {}
    fresh = bool(rv) and rv.get("at", 0) >= newest
    model = review.get("model") or {}
    model_dir = os.path.join(DOWNLOAD_ROOT, *model["dir"].split("/")) if model.get("dir") else ""
    model_images = images_in(model_dir) if model_dir else []
    target = (heights or {}).get(sid.split("/")[0])
    front = front_image(images)

    state = {"id": sid, "title": title, "images": [f"concept_art/{sid}/{n}" for n in images],
             "front": f"concept_art/{sid}/{front}" if front else None,
             "review": rv if fresh else None, "actions": [], "who": "",
             "model_images": [f"meshy_downloads/{model['dir']}/{n}" for n in model_images],
             "prompt": review.get("prompt"),
             "history": list(reversed(review.get("history", [])))[:12],
             "spend": (spend or {}).get(sid),
             "target": list(target) if target else None,
             "measured": model.get("measured_height_m"),
             "pack_approved": bool(review.get("pack_approved_at"))}
    if ticked or review.get("signed_off_at"):
        state.update(step=7, status="Done and in the game.", who="")
    elif not images:
        state.update(step=2, status="Waiting for the pack: generate it with Meshy (ask Claude) or save one here.",
                     who="you")
    elif not fresh:
        state.update(step=3, status="Pack is in. Waiting for Claude's review (ask Claude).", who="claude")
    elif not review.get("pack_approved_at"):
        state.update(step=4, status="Your call: approve the pack or re-roll it.", who="you",
                     actions=["approve_pack", "reroll_pack"])
    elif not model_images:
        state.update(step=5, status="Pack approved. Ready for Meshy (ask Claude; you approve the cost).",
                     who="claude", actions=["reroll_pack"])
    elif not review.get("model_approved_at"):
        state.update(step=5, status="Your call: approve the 3D model or regenerate it.", who="you",
                     actions=["approve_model", "regen_model"])
    else:
        state.update(step=6, status="3D approved. Claude puts it in the game; then you sign off.",
                     who="you", actions=["sign_off", "regen_model"])
    return state


# --------------------------------------------------------------- style bible

def style_bible() -> dict:
    try:
        with open(os.path.join(STYLE_DIR, "bible.json"), encoding="utf-8") as f:
            bible = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"status": "missing", "images": []}
    bible["images"] = [f"concept_art/_style_bible/{n}" for n in images_in(STYLE_DIR)]
    bible.setdefault("status", "draft")
    return bible


def approve_bible() -> str:
    path = os.path.join(STYLE_DIR, "bible.json")
    bible = style_bible()
    if bible["status"] == "missing":
        raise ValueError("there is no style bible to approve yet")
    bible.pop("images", None)
    bible["status"] = "approved"
    bible["approved_at"] = time.time()
    save_json(path, bible)
    return "Style bible approved."


# ----------------------------------------------------------------- actions

def record(review: dict, event: str, note: str) -> None:
    review.setdefault("history", []).append({"at": time.time(), "event": event, "note": note[:300]})


def do_action(sid: str, action: str, note: str, tool: str = "", text: str = "") -> str:
    subjects = discover_subjects(read_checklist())
    if sid not in subjects:
        raise ValueError("unknown subject")
    review = load_review(sid)
    now = time.time()
    if action == "save_prompt":
        text = text.strip()
        if tool not in PROMPT_TOOLS or not 1 <= len(text) <= 4000:
            raise ValueError("choose a tool and paste the prompt (up to 4000 characters)")
        review["prompt"] = {"tool": tool, "text": text, "at": now}
        record(review, f"Prompt saved ({tool})", "")
        save_review(sid, review)
        return "Prompt saved."
    state = subject_state(sid, subjects[sid]["title"], subjects[sid]["ticked"])
    if action not in state["actions"]:
        raise ValueError("that button does not apply right now; refresh the page")
    if action == "approve_pack":
        review["pack_approved_at"] = now
        record(review, "Pack approved", note)
    elif action == "reroll_pack":
        folder = subject_dir(sid)
        old = os.path.join(folder, "_old", time.strftime("%Y%m%d_%H%M%S"))
        os.makedirs(old, exist_ok=True)
        for n in images_in(folder):
            shutil.move(os.path.join(folder, n), os.path.join(old, n))
        review.pop("review", None)
        review["pack_approved_at"] = None
        review["model"] = None
        review["model_approved_at"] = None
        record(review, "Pack re-rolled (old images kept in _old)", note)
    elif action == "approve_model":
        review["model_approved_at"] = now
        record(review, "3D model approved", note)
    elif action == "regen_model":
        review["model"] = None
        review["model_approved_at"] = None
        record(review, "3D model sent back for regeneration", note)
    elif action == "sign_off":
        review["signed_off_at"] = now
        record(review, "Signed off", note)
        save_review(sid, review)
        ticked = tick_checklist(sid)
        return "Signed off and ticked on the checklist." if ticked else "Signed off (no checklist row to tick)."
    save_review(sid, review)
    return "Saved."


def do_race_action(rid: str, sex: str, step: str, action: str, note: str) -> str:
    """Approve or undo one step of a race's workflow; the in-game step also (un)ticks the checklist."""
    event = race_progress.apply(rid, sex, step, action, note)
    if step == "ingame":
        changed = tick_checklist(f"{rid}/{sex}", done=action == "approve")
        if changed:
            event += "; checklist " + ("ticked" if action == "approve" else "unticked")
    return event + "."


# ------------------------------------------------------------------ status

def credits() -> dict:
    out = {"balance": None, "checked_at": None, "tripwire": None}
    try:
        with open(STATUS_CACHE, encoding="utf-8") as f:
            data = json.load(f)
        out["balance"], out["checked_at"] = data.get("balance"), data.get("checked_at")
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    if os.path.exists(TRIPWIRE):
        try:
            with open(TRIPWIRE, encoding="utf-8") as f:
                out["tripwire"] = json.load(f)
        except (json.JSONDecodeError, OSError):
            out["tripwire"] = {"note": "tripwire file present"}
    return out


def board_state() -> dict:
    checklist = read_checklist()
    subjects = discover_subjects(checklist)
    heights = read_heights()
    spend, spend_total = spend_by_subject(read_ledger())
    # the concept-art (Meshy) cards: only subjects that have a pack, so the 32 checklist rows
    # with nothing made yet do not each show an empty card
    meshy = [st for st in (subject_state(sid, v["title"], v["ticked"], heights, spend) for sid, v in subjects.items())
             if st["images"]]
    out_credits = credits()
    out_credits["spent"] = spend_total
    sheets.DOWNLOAD_ROOT, sheets.DISCARD_ROOT, sheets.TASK_LEDGER = DOWNLOAD_ROOT, DISCARD_ROOT, TASK_LEDGER
    sheets.sweep_discards()
    cands = sheets.candidates()
    races = race_progress.race_states()
    for c in races:
        c["candidates"] = cands.get(c["id"], [])
        c["spend"] = spend.get(c["id"])
    others = sheets.other_sheets({c["id"] for c in races}, cands)
    for o in others:
        o["spend"] = spend.get(o["id"])
    return {
        "demo": DEMO,
        "sections": [{k: s[k] for k in ("num", "title", "done", "total", "items")} for s in checklist],
        "races": races,
        "others": others,
        "worker": race_progress.worker_status(),
        "race_steps": [label for _key, label in race_progress.STEPS],
        "subjects": meshy,
        "bible": style_bible(),
        "credits": out_credits,
        "steps": STEP_NAMES,
    }


# -------------------------------------------------------------------- HTTP

def safe_image_path(rel: str) -> str | None:
    parts = rel.split("/", 1)
    roots = {"concept_art": CONCEPT_ROOT, "meshy_downloads": DOWNLOAD_ROOT, "discarded": DISCARD_ROOT,
             "ref_art": race_progress.REF_ART, "board_cache": race_progress.CACHE_DIR}
    if len(parts) != 2 or parts[0] not in roots:
        return None
    root = os.path.realpath(roots[parts[0]])
    real = os.path.realpath(os.path.join(root, *parts[1].split("/")))
    try:
        inside = os.path.commonpath([real, root]) == root
    except ValueError:
        inside = False
    if not inside or os.path.splitext(real)[1].lower() not in IMAGE_EXT or not os.path.isfile(real):
        return None
    return real


class Handler(BaseHTTPRequestHandler):
    port = 0

    def log_message(self, fmt, *args):
        pass

    def _host_ok(self) -> bool:
        return self.headers.get("Host", "") in (f"127.0.0.1:{self.port}", f"localhost:{self.port}")

    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code: int, obj) -> None:
        self._send(code, json.dumps(obj).encode("utf-8"), "application/json")

    def do_GET(self):
        if not self._host_ok():
            return self._send(403, b"forbidden", "text/plain")
        url = urlparse(self.path)
        if url.path == "/":
            return self._send(200, PAGE.replace("__TOKEN__", TOKEN).encode("utf-8"), "text/html; charset=utf-8")
        if url.path == "/api/state":
            return self._json(200, board_state())
        if url.path == "/img":
            real = safe_image_path(parse_qs(url.query).get("p", [""])[0])
            if not real:
                return self._send(404, b"not found", "text/plain")
            with open(real, "rb") as f:
                data = f.read()
            return self._send(200, data, mimetypes.guess_type(real)[0] or "application/octet-stream")
        self._send(404, b"not found", "text/plain")

    def do_POST(self):
        if not self._host_ok() or self.headers.get("X-Board-Token") != TOKEN:
            return self._send(403, b"forbidden", "text/plain")
        if urlparse(self.path).path != "/api/action":
            return self._send(404, b"not found", "text/plain")
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 20000)
            body = json.loads(self.rfile.read(length).decode("utf-8"))
            action = str(body.get("action", ""))
            if action == "approve_bible":
                message = approve_bible()
            elif action in ("use_sheet", "discard_sheet", "restore_sheet"):
                sheets.DOWNLOAD_ROOT, sheets.DISCARD_ROOT, sheets.TASK_LEDGER = DOWNLOAD_ROOT, DISCARD_ROOT, TASK_LEDGER
                rel = str(body.get("path", ""))
                if action == "use_sheet":
                    names = {rid: name for rid, name, _lo, _hi in race_progress.read_races()}
                    message = sheets.use(rel, names)
                else:
                    message = sheets.set_state(rel, "discarded" if action == "discard_sheet" else "new")
            elif action in ("approve_step", "undo_step"):
                rid = str(body.get("race", ""))
                if not SUBJECT_RE.match(rid) or "/" in rid:
                    raise ValueError("bad race id")
                message = do_race_action(rid, str(body.get("sex", "")), str(body.get("step", "")),
                                         action.split("_")[0], str(body.get("note", "")))
            else:
                sid = str(body.get("subject", ""))
                if not SUBJECT_RE.match(sid):
                    raise ValueError("bad subject id")
                message = do_action(sid, action, str(body.get("note", "")),
                                    str(body.get("tool", "")), str(body.get("text", "")))
            self._json(200, {"ok": True, "message": message})
        except Exception as exc:
            self._json(400, {"ok": False, "message": html.escape(str(exc))})


# -------------------------------------------------------------------- demo

def _png(w: int, h: int, rows: list) -> bytes:
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


# Placeholder bodies for the demo only: colour, head height, torso width, leg width,
# arm width (fractions of the figure). Real packs come from Grok or Gemini.
DEMO_BODIES = {
    "fae":      ((176, 196, 226), 0.19, 0.20, 0.07, 0.05),
    "gnome":    ((206, 168, 136), 0.20, 0.36, 0.12, 0.07),
    "halfling": ((196, 150, 112), 0.18, 0.32, 0.11, 0.07),
    "dwarf":    ((172, 120, 88), 0.16, 0.44, 0.15, 0.09),
    "elf":      ((216, 198, 168), 0.12, 0.22, 0.08, 0.05),
    "human":    ((194, 158, 128), 0.13, 0.28, 0.10, 0.06),
    "ogre":     ((124, 142, 98), 0.10, 0.46, 0.17, 0.11),
}


def figure_png(race: str, view: str, dark: bool = False, w: int = 150, h: int = 300) -> bytes:
    """A flat placeholder figure: head, torso, A-pose arms and legs."""
    color, head, torso, leg, arm = DEMO_BODIES[race]
    bg = bytes((36, 38, 48, 255) if dark else (212, 212, 207, 255))
    top, height, cx = h * 0.02, h * 0.97, w / 2
    spread = {"side": 0.5, "three_quarter": 0.8}.get(view, 1.0)
    tw, lw, aw = torso * w / 2 * spread, leg * w / 2, arm * w / 2
    hr = head * height / 2
    shoulder, hip, foot = top + head * height + 0.02 * height, top + 0.56 * height, top + height
    hand_y = top + 0.55 * height
    if view == "side":
        legs, arms = [0.0], [(cx, shoulder + aw, cx + 0.03 * w, hand_y)]
        lw *= 1.2
    else:
        reach = 0.10 * w if view == "three_quarter" else 0.16 * w
        legs = [-tw * 0.5, tw * 0.5]
        arms = [(cx - tw, shoulder + aw, cx - tw - reach, hand_y), (cx + tw, shoulder + aw, cx + tw + reach, hand_y)]
    tint = 0.84 if view == "back" else 1.0
    rows = []
    for y in range(h):
        row = bytearray(bg * w)
        ny = (y - top) / height
        if 0 <= ny <= 1:
            shade = max(0.55, 1.12 - 0.45 * ny) * tint * (1.15 if dark else 1.0)
            c = bytes(min(255, int(ch * shade)) for ch in color) + b"\xff"
            spans = []
            dy = y - (top + hr)
            if abs(dy) <= hr:
                half = math.sqrt(hr * hr - dy * dy) * 0.85
                spans.append((cx - half, cx + half))
            if shoulder <= y <= hip:
                t = (y - shoulder) / (hip - shoulder)
                spans.append((cx - tw * (1 - 0.12 * t), cx + tw * (1 - 0.12 * t)))
            if hip <= y <= foot:
                spans += [(cx + off - lw, cx + off + lw) for off in legs]
            for x0, y0, x1, y1 in arms:
                if y0 <= y <= y1:
                    xc = x0 + (x1 - x0) * (y - y0) / (y1 - y0)
                    spans.append((xc - aw, xc + aw))
            for a, b in spans:
                a, b = max(0, int(a)), min(w, int(b) + 1)
                if b > a:
                    row[a * 4:b * 4] = c * (b - a)
        rows.append(row)
    return _png(w, h, rows)


def palette_png(w: int = 300, h: int = 80) -> bytes:
    bands = [(94, 74, 56), (140, 110, 80), (176, 150, 112), (110, 120, 90), (80, 90, 100), (160, 90, 60)]
    row = bytearray()
    for x in range(w):
        row += bytes(bands[x * len(bands) // w]) + b"\xff"
    return _png(w, h, [row] * h)


def build_demo() -> str:
    """Fill a throwaway folder with sample subjects at every step, and point the board at it."""
    global CHECKLIST, STATUS_CACHE, TRIPWIRE, TASK_LEDGER, CONCEPT_ROOT, DOWNLOAD_ROOT, DISCARD_ROOT, STYLE_DIR, DEMO
    sandbox = tempfile.mkdtemp(prefix="art_board_demo_")
    real_checklist = CHECKLIST
    CHECKLIST = os.path.join(sandbox, "art_assets_checklist.md")
    shutil.copy(real_checklist, CHECKLIST)
    STATUS_CACHE, TRIPWIRE = os.path.join(sandbox, "status.json"), os.path.join(sandbox, "tripwire.json")
    TASK_LEDGER = os.path.join(sandbox, "task_ledger.json")
    CONCEPT_ROOT, DOWNLOAD_ROOT = os.path.join(sandbox, "concept_art"), os.path.join(sandbox, "meshy_downloads")
    DISCARD_ROOT = os.path.join(sandbox, "discarded")
    STYLE_DIR = os.path.join(CONCEPT_ROOT, "_style_bible")
    DEMO = True
    # the race cards read the real model files (read-only) but keep approvals and renders here
    race_progress.PROGRESS = os.path.join(sandbox, "progress.json")
    race_progress.CACHE_DIR = os.path.join(sandbox, "board_cache")

    views =[("1_front", "front"), ("2_side", "side"), ("3_back", "back"), ("4_three_quarter", "three_quarter")]
    thumbs = [("thumb_front", "front"), ("thumb_right", "side"), ("thumb_back", "back"), ("thumb_left", "side")]
    day = 86400
    now = time.time()
    checks = ["Views agree", "Matches race file", "Style bible", "A-pose, arms clear", "Flat lighting", "Plain background"]
    prompt = ("Fantasy character concept art turnaround model sheet, {who}, clean digital painting with soft "
              "even shading, semi-realistic anatomy, muted earthy palette, matte materials, crisp silhouette, "
              "plain light-grey background, flat even studio lighting, no cast shadows, no brushstroke texture, no text.")

    def pack(sid):
        d = os.path.join(CONCEPT_ROOT, *sid.split("/"))
        os.makedirs(d, exist_ok=True)
        for name, view in views:
            with open(os.path.join(d, name + ".png"), "wb") as f:
                f.write(figure_png(sid.split("/")[0], view))

    def model(sid, task):
        d = os.path.join(DOWNLOAD_ROOT, sid.replace("/", "_"), task)
        os.makedirs(d, exist_ok=True)
        for name, view in thumbs:
            with open(os.path.join(d, name + ".png"), "wb") as f:
                f.write(figure_png(sid.split("/")[0], view, dark=True))
        return f"{sid.replace('/', '_')}/{task}"

    def reviewed(failed=None, summary="Views agree and the build matches the race file."):
        return {"at": now + 5, "summary": summary,
                "checks": [{"label": c, "ok": c != failed, "note": "" if c != failed else failed_note} for c in checks]}

    failed_note = "Left hand touches the hip in the side view; the rigger needs clear arms."
    subjects = {
        "ogre/male": {"model": ("demo_ogre_01", 2.55), "approved_model": True, "signed": True,
                      "prompt": ("Gemini", prompt.format(who="a male Ogre, massive shoulders, long arms"))},
        "human/male": {"model": ("demo_human_01", 1.79), "approved_model": True,
                       "prompt": ("Gemini", prompt.format(who="a male Human adventurer in a linen tunic"))},
        "dwarf/female": {"model": ("demo_dwarf_01", 1.41),
                         "prompt": ("Grok", prompt.format(who="a female Dwarf, barrel chest, braided hair"))},
        "gnome/male": {"failed": "A-pose, arms clear",
                       "prompt": ("Gemini", prompt.format(who="a male Gnome, wiry, goggles, singed beard"))},
        "halfling/male": {"approved_pack": True},
        "elf/female": {"no_review": True},
        "fae/female": {"no_review": True},
    }
    for sid in subjects:
        pack(sid)
    ledger = {}
    for sid, spec in subjects.items():
        review = {"history": []}
        if not spec.get("no_review"):
            review["review"] = reviewed(spec.get("failed"))
        if spec.get("prompt"):
            review["prompt"] = {"tool": spec["prompt"][0], "text": spec["prompt"][1], "at": now - 3 * day}
        if sid == "gnome/male":
            review["history"].append({"at": now - 2 * day, "event": "Pack re-rolled (old images kept in _old)",
                                      "note": "Head too big for the style bible; proportions read cartoonish."})
        if spec.get("approved_pack") or spec.get("model"):
            review["pack_approved_at"] = now - day
            review["history"].append({"at": now - day, "event": "Pack approved", "note": ""})
        if spec.get("model"):
            task, measured = spec["model"]
            review["model"] = {"dir": model(sid, task), "task_id": task, "measured_height_m": measured}
            ledger[task] = {"type": "multi-image-to-3d", "expected": 30, "consumed": 30, "subject": sid}
        if spec.get("approved_model"):
            review["model_approved_at"] = now - day / 2
            review["history"].append({"at": now - day / 2, "event": "3D model approved", "note": ""})
            ledger[task + "_rig"] = {"type": "rigging", "expected": 5, "consumed": 5, "subject": sid}
        if spec.get("signed"):
            review["signed_off_at"] = now - day / 4
            review["history"].append({"at": now - day / 4, "event": "Signed off", "note": ""})
            tick_checklist(sid)
        save_review(sid, review)

    # generated model sheets: a copy of the real ref_art sheets to replace, two Half-Ogre
    # candidates (one already in use) and an "Other sheets" subject with a fresh candidate
    sandbox_ref = os.path.join(sandbox, "ref_art")
    os.makedirs(sandbox_ref, exist_ok=True)
    if os.path.isdir(race_progress.REF_ART):
        for n in os.listdir(race_progress.REF_ART):
            if race_progress.PACK_RE.match(n) and os.path.isfile(os.path.join(race_progress.REF_ART, n)):
                shutil.copy2(os.path.join(race_progress.REF_ART, n), os.path.join(sandbox_ref, n))
    race_progress.REF_ART = sandbox_ref
    sheets.DECISIONS = os.path.join(sandbox, "sheets.json")
    sheet_prompt = ("Fantasy character model sheet, 16:9, titled \"{t} Male & Female 2D Model Pack\", "
                    "matching the attached sheet's layout and rendering exactly...")
    image_tasks = [
        ("demo-img-halfogre-01", "half_ogre", "image-to-image", ["ModelPack_Ogre.png"], 2 * day,
         lambda: figure_png("ogre", "front", w=300, h=170)),
        ("demo-img-halfogre-02", "half_ogre", "image-to-image", ["ModelPack_Ogre.png"], day,
         lambda: figure_png("ogre", "three_quarter", w=300, h=170)),
        ("demo-img-blacksmithing-01", "blacksmithing", "text-to-image", [], day / 3,
         lambda: palette_png(300, 170)),
    ]
    for task, subject, kind, refs, age, make in image_tasks:
        d = os.path.join(DOWNLOAD_ROOT, subject, task)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "image_1.png"), "wb") as f:
            f.write(make())
        ledger[task] = {"type": kind, "expected": 3, "consumed": 3, "subject": subject,
                        "created": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(now - age)),
                        "prompt": sheet_prompt.format(t=subject.replace("_", "-").title()),
                        "ai_model": "nano-banana", "aspect_ratio": "16:9", "references": refs}
    save_json(sheets.DECISIONS, {"demo-img-halfogre-01/image_1.png":
                                 {"state": "discarded", "subject": "half_ogre", "at": now - day}})
    save_json(TASK_LEDGER, ledger)
    save_json(STATUS_CACHE, {"balance": 3513 - sum(e["consumed"] for e in ledger.values()), "checked_at": now - 600})

    os.makedirs(STYLE_DIR, exist_ok=True)
    with open(os.path.join(STYLE_DIR, "1_palette.png"), "wb") as f:
        f.write(palette_png())
    with open(os.path.join(STYLE_DIR, "2_reference_human.png"), "wb") as f:
        f.write(figure_png("human", "front"))
    save_json(os.path.join(STYLE_DIR, "bible.json"), {
        "status": "approved", "approved_at": now - 4 * day,
        "summary": ("EverQuest-like: semi-realistic anatomy, strong size differences between races, muted "
                    "earthy palette. Clean concept-art model sheets, soft even shading, flat even lighting."),
        "prompt_template": prompt.format(who="{race and sex, two or three defining features}")})
    return sandbox


# -------------------------------------------------------------------- main

def main() -> None:
    demo = "--demo" in sys.argv[1:]
    if demo:
        sandbox = build_demo()
        print(f"Demo data in {sandbox} (throwaway; your real board is untouched)")
    for port in (DEMO_PORTS if demo else PORTS):
        try:
            Handler.port = port
            server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
            break
        except OSError:
            continue
    else:
        sys.exit("No free port; is the board already open?")
    url = f"http://127.0.0.1:{port}/"
    print(f"Art Board running at {url}  (close this window to stop it)", flush=True)
    if "--no-browser" not in sys.argv[1:]:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


PAGE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Project Dawn Art Board</title>
<style>
:root{--bg:#07080c;--glass:rgba(18,20,28,.72);--glass2:rgba(26,28,38,.85);--line:rgba(212,170,92,.18);
--line2:rgba(212,170,92,.45);--text:#ece6d8;--dim:#9b9384;--gold:#e0b25e;--gold2:#f6d999;
--ember:#e2734d;--rose:#c4567a;--green:#6fc28a;--red:#e0605a;
--serif:"Palatino Linotype","Book Antiqua",Palatino,Georgia,serif;--sans:"Segoe UI",system-ui,sans-serif}
*{box-sizing:border-box}
html{background:var(--bg)}
body{margin:0;min-height:100vh;color:var(--text);font:15px/1.5 var(--serif);
background:
 radial-gradient(1px 1px at 12% 18%,rgba(255,255,255,.55),transparent 60%),
 radial-gradient(1px 1px at 27% 8%,rgba(255,255,255,.35),transparent 60%),
 radial-gradient(1.5px 1.5px at 44% 22%,rgba(255,240,210,.5),transparent 60%),
 radial-gradient(1px 1px at 63% 12%,rgba(255,255,255,.4),transparent 60%),
 radial-gradient(1px 1px at 78% 26%,rgba(255,255,255,.3),transparent 60%),
 radial-gradient(1.5px 1.5px at 89% 9%,rgba(255,230,200,.45),transparent 60%),
 radial-gradient(1px 1px at 35% 34%,rgba(255,255,255,.25),transparent 60%),
 radial-gradient(1px 1px at 71% 40%,rgba(255,255,255,.2),transparent 60%),
 radial-gradient(2px 2px at 18% 46%,rgba(255,255,255,.35),transparent 60%),
 radial-gradient(1.5px 1.5px at 54% 52%,rgba(255,245,220,.3),transparent 60%),
 radial-gradient(1.5px 1.5px at 92% 38%,rgba(255,255,255,.35),transparent 60%),
 radial-gradient(1px 1px at 6% 30%,rgba(255,255,255,.4),transparent 60%),
 radial-gradient(ellipse 110% 46% at 50% -8%,rgba(226,115,77,.55),rgba(196,86,122,.22) 42%,transparent 72%),
 radial-gradient(ellipse 55% 20% at 50% -4%,rgba(246,217,153,.45),transparent 70%),
 linear-gradient(#0b0c13,#07080c 420px);background-attachment:fixed}
header{position:sticky;top:0;z-index:5;backdrop-filter:blur(10px);background:rgba(7,8,12,.35);
border-bottom:1px solid var(--line);padding:14px 26px;display:flex;flex-wrap:wrap;gap:12px;align-items:center}
.sun{width:34px;height:18px;position:relative;overflow:hidden;margin-right:4px}
.sun::before{content:"";position:absolute;left:5px;top:4px;width:24px;height:24px;border-radius:50%;
background:radial-gradient(circle at 50% 60%,var(--gold2),var(--gold) 45%,var(--ember) 80%);
box-shadow:0 0 18px 4px rgba(226,140,77,.55)}
.sun::after{content:"";position:absolute;left:0;right:0;bottom:0;height:2px;background:linear-gradient(90deg,transparent,var(--gold2),transparent)}
h1{font:600 22px var(--serif);margin:0 14px 0 0;letter-spacing:2px;font-variant:small-caps;
background:linear-gradient(180deg,var(--gold2),var(--gold) 55%,#b9803a);-webkit-background-clip:text;background-clip:text;color:transparent}
.chip{padding:5px 12px;border-radius:999px;border:1px solid var(--line);background:rgba(20,22,30,.6);font:13px var(--sans);color:var(--text)}
.ok{border-color:rgba(111,194,138,.5);color:var(--green);box-shadow:0 0 10px rgba(111,194,138,.12) inset}
.bad{border-color:var(--red);color:#fff;background:rgba(224,96,90,.85);box-shadow:0 0 18px rgba(224,96,90,.55)}
.demochip{border-color:var(--rose);color:#f3c1d1;background:rgba(196,86,122,.18)}
main{padding:10px 26px 60px;max-width:1240px;margin:auto}
.demo{margin:18px 0 0;padding:10px 16px;border:1px dashed var(--rose);border-radius:8px;color:#f3c1d1;
font:14px var(--sans);background:rgba(196,86,122,.08)}
h2{display:flex;align-items:center;gap:14px;font:600 15px var(--serif);letter-spacing:3px;text-transform:uppercase;
color:var(--gold);margin:34px 0 14px}
h2::before,h2::after{content:"";flex:1;height:1px;background:linear-gradient(90deg,transparent,var(--line2),transparent)}
h2::before{max-width:40px}
.empty{grid-column:1/-1;color:var(--dim);font-style:italic;padding:6px 2px}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(350px,1fr));gap:18px}
.card,.bible{position:relative;background:linear-gradient(160deg,var(--glass2),var(--glass));border:1px solid var(--line);
border-radius:10px;padding:16px 18px;box-shadow:0 10px 30px rgba(0,0,0,.45);transition:transform .2s,border-color .2s}
.card:hover{transform:translateY(-2px);border-color:var(--line2)}
.card::before,.card::after,.bible::before,.bible::after{content:"";position:absolute;width:14px;height:14px;border:1px solid var(--gold);opacity:.55}
.card::before,.bible::before{top:6px;left:6px;border-right:0;border-bottom:0}
.card::after,.bible::after{bottom:6px;right:6px;border-left:0;border-top:0}
.card.you{border-color:var(--line2);animation:glow 3.2s ease-in-out infinite}
@keyframes glow{0%,100%{box-shadow:0 10px 30px rgba(0,0,0,.45),0 0 0 rgba(224,178,94,0)}
50%{box-shadow:0 10px 30px rgba(0,0,0,.45),0 0 26px rgba(224,150,80,.28)}}
.card h3{margin:2px 0 2px;font:600 19px var(--serif);color:var(--text)}
.sid{color:var(--dim);font:12px Consolas,monospace;letter-spacing:.5px}
.steps{position:relative;display:flex;justify-content:space-between;margin:14px 6px 10px}
.steps::before{content:"";position:absolute;left:0;right:0;top:50%;height:1px;background:var(--line2)}
.dot{position:relative;width:11px;height:11px;transform:rotate(45deg);background:var(--bg);border:1px solid var(--line2)}
.dot.done{background:var(--gold);border-color:var(--gold)}
.dot.now{background:var(--gold2);border-color:var(--gold2);box-shadow:0 0 12px 3px rgba(246,200,120,.6)}
.status{font:14px var(--sans);margin:6px 0 10px;color:#ddd5c4}
.who{font:600 10px var(--sans);text-transform:uppercase;letter-spacing:2px;color:var(--dim)}
.card.you .who{color:var(--gold2)}
.imgs{display:flex;gap:8px;flex-wrap:wrap;margin:6px 0}
.imgs img{height:100px;border-radius:4px;border:1px solid var(--line2);background:#000;cursor:zoom-in;
box-shadow:0 4px 12px rgba(0,0,0,.5);transition:transform .15s}
.imgs img:hover{transform:scale(1.04)}
.label{font:600 10px var(--sans);text-transform:uppercase;letter-spacing:2px;color:var(--dim);margin-top:12px}
.checks{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0}
.check{font:12px var(--sans);padding:3px 9px;border-radius:999px;border:1px solid}
.check.pass{background:rgba(111,194,138,.10);color:#a8e6bd;border-color:rgba(111,194,138,.35)}
.check.fail{background:rgba(224,96,90,.12);color:#f4b0aa;border-color:rgba(224,96,90,.4)}
.failnote{font:13px var(--sans);color:#f4b0aa;margin:2px 0 4px}
.summary{font-size:14.5px;color:var(--text);font-style:italic}
.facts{display:flex;flex-wrap:wrap;gap:8px;margin:8px 0 2px;font:13px var(--sans)}
.fact{padding:3px 10px;border-radius:6px;background:rgba(255,255,255,.04);border:1px solid var(--line)}
.fact.good{border-color:rgba(111,194,138,.45);color:#a8e6bd}.fact.warn{border-color:rgba(224,96,90,.5);color:#f4b0aa}
pre{white-space:pre-wrap;word-break:break-word;margin:6px 0;padding:8px 10px;border-radius:6px;font:12.5px/1.45 Consolas,monospace;
background:rgba(7,8,12,.6);border:1px solid var(--line);color:#d9d1bf;max-height:7.5em;overflow:auto}
.ptool{font:12px var(--sans);color:var(--dim)}
details.pedit,details.hist{margin-top:8px;font:13px var(--sans)}
details.pedit summary,details.hist summary{cursor:pointer;color:var(--gold);list-style:none}
details.pedit summary::-webkit-details-marker,details.hist summary::-webkit-details-marker{display:none}
details.pedit textarea,details.pedit select{width:100%;margin-top:6px;padding:6px 8px;border-radius:6px;border:1px solid var(--line);
background:rgba(7,8,12,.7);color:var(--text);font:12.5px Consolas,monospace}
details.pedit select{width:auto;font:13px var(--sans)}
.hrow{padding:4px 0;border-top:1px solid rgba(255,255,255,.04)}.hrow .when{color:var(--dim);font-size:12px;margin-right:6px}
.hrow .hnote{color:#cfc6b3;font-style:italic}
.btns{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
button{font:600 13px var(--sans);letter-spacing:.5px;padding:8px 16px;border-radius:6px;border:1px solid var(--line2);
background:rgba(40,42,54,.8);color:var(--text);cursor:pointer;transition:all .15s}
button:hover{transform:translateY(-1px)}
button.mini{padding:4px 10px;font-size:12px}
button.go{background:linear-gradient(180deg,rgba(111,194,138,.32),rgba(60,120,80,.32));border-color:rgba(111,194,138,.6)}
button.go:hover{box-shadow:0 0 14px rgba(111,194,138,.4)}
button.back{background:linear-gradient(180deg,rgba(226,115,77,.30),rgba(150,60,40,.30));border-color:rgba(226,115,77,.6)}
button.back:hover{box-shadow:0 0 14px rgba(226,115,77,.4)}
input.note{width:100%;margin-top:10px;padding:7px 10px;border-radius:6px;border:1px solid var(--line);
background:rgba(7,8,12,.7);color:var(--text);font:13px var(--sans)}
input.note:focus,textarea:focus{outline:none;border-color:var(--line2)}
.bible{margin-top:20px}.bible.missing{border-style:dashed}
.btitle{display:flex;align-items:center;gap:10px;font:600 18px var(--serif);color:var(--gold2)}
.lineup{background:linear-gradient(160deg,var(--glass2),var(--glass));border:1px solid var(--line);border-radius:10px;padding:16px 18px}
.stage{position:relative;overflow-x:auto}
.rline{position:absolute;left:0;right:0;height:1px;background:rgba(224,178,94,.14)}
.rline span{position:absolute;left:4px;top:-9px;font:11px var(--sans);color:var(--dim)}
.figs{position:absolute;left:52px;bottom:0;display:flex;align-items:flex-end;gap:26px;padding-right:20px}
.fig{display:flex;flex-direction:column;align-items:center;min-width:70px}
.fig img{display:block;border-radius:3px;cursor:zoom-in;box-shadow:0 0 18px rgba(0,0,0,.6)}
.fig.draft img{opacity:.45;outline:1px dashed var(--dim)}
.fl{height:22px;margin-top:6px;font:600 13px var(--serif);white-space:nowrap}.fh{height:18px;font:12px var(--sans);color:var(--dim)}
.hint{margin-top:10px;font:12.5px var(--sans);color:var(--dim)}
.sec{background:linear-gradient(160deg,var(--glass2),var(--glass));border:1px solid var(--line);border-radius:8px;margin-bottom:8px}
.sec[open]{border-color:var(--line2)}
.sec summary{cursor:pointer;padding:11px 16px;display:flex;gap:14px;align-items:center;list-style:none}
.sec summary::-webkit-details-marker{display:none}
.sec .name{flex:0 0 270px;font:600 15px var(--serif)}
.bar{flex:1;height:8px;background:rgba(255,255,255,.06);border-radius:4px;overflow:hidden;border:1px solid rgba(255,255,255,.04)}
.fill{height:100%;background:linear-gradient(90deg,var(--rose),var(--ember),var(--gold2));box-shadow:0 0 10px rgba(226,150,80,.5)}
.count{flex:0 0 70px;text-align:right;font:13px var(--sans);color:var(--dim)}
.rows{padding:0 16px 14px 16px;font:14px var(--sans)}
.row{padding:4px 0;display:flex;gap:10px;align-items:center;border-top:1px solid rgba(255,255,255,.03)}
.row .grp{color:var(--dim);font-size:12px}
.box{width:11px;height:11px;flex:0 0 11px;transform:rotate(45deg);border:1px solid var(--dim);margin:0 3px;font-size:0}
.box.on{background:var(--gold);border-color:var(--gold);box-shadow:0 0 8px rgba(224,178,94,.6)}
.pill{font-size:11px;padding:1px 8px;border-radius:999px;background:rgba(224,178,94,.12);color:var(--gold2);border:1px solid var(--line2)}
#toast{position:fixed;bottom:22px;left:50%;transform:translateX(-50%);background:rgba(20,22,30,.92);border:1px solid var(--line2);
padding:10px 18px;border-radius:8px;font:14px var(--sans);display:none;box-shadow:0 0 24px rgba(224,150,80,.25);z-index:8}
#zoom{position:fixed;inset:0;background:rgba(4,4,8,.9);display:none;align-items:center;justify-content:center;z-index:9}
#zoom img{max-width:94vw;max-height:94vh;border:1px solid var(--line2);box-shadow:0 0 60px rgba(224,150,80,.2)}
.race .rhead{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}
.packthumb{height:70px;border-radius:4px;border:1px solid var(--line2);cursor:zoom-in;box-shadow:0 4px 12px rgba(0,0,0,.5)}
.sexline{display:flex;gap:14px;margin-top:12px;padding-top:10px;border-top:1px solid var(--line)}
.sexmain{flex:1;min-width:0}
.sexname{font:600 11px var(--sans);letter-spacing:2px;text-transform:uppercase;color:var(--gold)}
.track{position:relative;display:grid;grid-template-columns:repeat(7,1fr);margin:8px 0 6px}
.track::before{content:"";position:absolute;left:7%;right:7%;top:5px;height:1px;background:var(--line2)}
.stp{position:relative;display:flex;flex-direction:column;align-items:center;gap:5px;font:10px var(--sans);color:var(--dim);text-align:center}
.dot.approved{background:var(--gold);border-color:var(--gold)}
.dot.ready{background:var(--ember);border-color:var(--gold2);box-shadow:0 0 10px 2px rgba(226,115,77,.6)}
.dot.changed{background:#d9a441;border-color:#f0c060;box-shadow:0 0 8px rgba(240,192,96,.5)}
.stp.cur{color:var(--gold2)}
.status.you{color:var(--gold2)}.status.todo{color:#cfc6b3}
.srow{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:3px 0;font:12.5px var(--sans)}
.slabel{color:var(--dim);font-size:11px;min-width:62px}
.render{height:130px;align-self:flex-end;cursor:zoom-in;filter:drop-shadow(0 0 10px rgba(0,0,0,.6))}
.later{display:flex;flex-wrap:wrap;gap:8px}
.cands{display:flex;flex-direction:column;gap:10px;margin-top:6px}
.cand{display:flex;gap:12px;padding:10px;border-radius:8px;border:1px solid var(--line);background:rgba(255,255,255,.025)}
.cand.used{border-color:rgba(111,194,138,.6);background:rgba(111,194,138,.07)}
.cand.discarded{opacity:.45}
.cand img{height:110px;border-radius:4px;border:1px solid var(--line2);background:#000;cursor:zoom-in;flex:none}
.cand .cmeta{flex:1;min-width:0;font:12.5px var(--sans);color:var(--dim)}
.cand .cmeta b{color:var(--text);font-weight:600}
.cand .btns{margin-top:8px}
.cand details summary{cursor:pointer;margin-top:6px}
.badge{display:inline-block;padding:1px 8px;border-radius:10px;font:600 11px var(--sans);margin-right:6px;
border:1px solid var(--line2);color:var(--gold2)}.badge.used{border-color:rgba(111,194,138,.6);color:#a8e6bd}
.later .chip{cursor:default}
.figs img{box-shadow:none;filter:drop-shadow(0 0 12px rgba(0,0,0,.7))}
@media (max-width:640px){header,main{padding-left:16px;padding-right:16px}.sec .name{flex-basis:140px}
.sexline{flex-direction:column}.render{align-self:center}}
@media (prefers-reduced-motion:reduce){.card.you{animation:none}*{transition:none!important}}
</style></head><body>
<header><span class="sun"></span><h1>Project Dawn Art Board</h1><span id="ingame" class="chip">...</span>
<span id="overall" class="chip">...</span><span id="worker" class="chip"></span>
<span id="credits" class="chip">Credits: ...</span><span id="spent" class="chip">Spent on art: ...</span>
<span id="trip" class="chip">Tripwire: ...</span><span id="demochip"></span></header>
<main>
<div id="demo"></div>
<h2>Your turn</h2><div id="yours" class="cards"></div>
<h2>In progress</h2><div id="progress" class="cards"></div>
<h2>Lineup</h2><div id="lineup"></div>
<div id="donewrap"></div>
<h2>Not started</h2><div id="notstarted"></div>
<h2>Other sheets</h2><div id="others" class="cards"></div>
<h2>Checklist</h2><div id="sections"></div>
<h2>Meshy and concept art</h2>
<details class="sec" id="meshysec"><summary><span class="name">Shelved: the style bible and the Meshy cards</span>
<span class="count" id="meshycount"></span></summary><div class="rows"><div id="bible"></div>
<div id="meshycards" class="cards" style="margin-top:16px"></div></div></details>
</main>
<div id="toast"></div><div id="zoom" onclick="this.style.display='none'"><img id="zoomimg" alt=""></div>
<script>
const TOKEN="__TOKEN__";
const LABELS={approve_pack:"Approve pack",reroll_pack:"Re-roll pack",approve_model:"Approve 3D",
regen_model:"Regenerate 3D",sign_off:"Sign off"};
const GOOD=new Set(["approve_pack","approve_model","sign_off"]);
let STEPS=[],openSecs=new Set(),openEdits=new Set(),TEXTS={};
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const url=p=>"/img?p="+encodeURIComponent(p);
const when=t=>new Date(t*1000).toLocaleString([],{month:"short",day:"numeric",hour:"2-digit",minute:"2-digit"});
function toast(t){const e=document.getElementById("toast");e.textContent=t;e.style.display="block";setTimeout(()=>e.style.display="none",2600)}
function zoom(src){document.getElementById("zoomimg").src=src;document.getElementById("zoom").style.display="flex"}
function imgs(list){return list.length?`<div class="imgs">${list.map(p=>`<img src="${url(p)}" loading="lazy" onclick="zoom('${url(p)}')" title="${esc(p.split('/').pop())}">`).join("")}</div>`:""}
async function copy(key){const t=TEXTS[key]||"";try{await navigator.clipboard.writeText(t)}catch(e){
 const a=document.createElement("textarea");a.value=t;document.body.appendChild(a);a.select();document.execCommand("copy");a.remove()}toast("Copied")}
async function post(body){const r=await fetch("/api/action",{method:"POST",headers:{"Content-Type":"application/json","X-Board-Token":TOKEN},
 body:JSON.stringify(body)});const j=await r.json();toast(j.message);load(true)}
function act(id,action){
 if(action==="reroll_pack"&&!confirm("Re-roll this pack? The current images move to an _old folder."))return;
 const note=(document.getElementById("note-"+id)||{}).value||"";post({subject:id,action,note})}
function savePrompt(id){post({subject:id,action:"save_prompt",tool:document.getElementById("tool-"+id).value,
 text:document.getElementById("ptext-"+id).value});openEdits.delete(id)}
function te(el){const id=el.dataset.id;el.open?openEdits.add(id):openEdits.delete(id)}
function facts(s){const f=[];
 if(s.target){const[lo,hi]=s.target;if(s.measured!=null){const ok=s.measured>=lo*0.98&&s.measured<=hi*1.02;
  f.push(`<span class="fact ${ok?"good":"warn"}">${ok?"&#10003;":"&#10007;"} Height ${s.measured.toFixed(2)} m, target ${lo.toFixed(2)} to ${hi.toFixed(2)} m</span>`)}
  else f.push(`<span class="fact">Target height ${lo.toFixed(2)} to ${hi.toFixed(2)} m</span>`)}
 if(s.spend)f.push(`<span class="fact">Credits used: ${s.spend.credits}${s.spend.estimated?" (estimate)":""}</span>`);
 return f.length?`<div class="facts">${f.join("")}</div>`:""}
function promptBlock(s){const p=s.prompt,key="p:"+s.id;let out=`<div class="label">Prompt</div>`;
 if(p){TEXTS[key]=p.text;out+=`<div class="ptool">${esc(p.tool)}, saved ${when(p.at)}</div><pre>${esc(p.text)}</pre><button class="mini" onclick="copy('${key}')">Copy prompt</button>`}
 else out+=`<div class="empty">No prompt saved for this pack yet.</div>`;
 return out+`<details class="pedit" data-id="${esc(s.id)}" ${openEdits.has(s.id)?"open":""} ontoggle="te(this)">
 <summary>${p?"Replace the prompt":"Save the prompt you used"}</summary>
 <select id="tool-${esc(s.id)}"><option>Gemini</option><option>Grok</option><option>Other</option></select>
 <textarea id="ptext-${esc(s.id)}" rows="4" placeholder="Paste the exact prompt"></textarea>
 <button class="mini go" onclick="savePrompt('${esc(s.id)}')">Save prompt</button></details>`}
function history(s){if(!s.history.length)return"";
 return `<details class="hist"><summary>History (${s.history.length})</summary>${s.history.map(h=>
 `<div class="hrow"><span class="when">${when(h.at)}</span>${esc(h.event)}${h.note?` <span class="hnote">"${esc(h.note)}"</span>`:""}</div>`).join("")}</details>`}
function card(s){
 const dots=[1,2,3,4,5,6].map(i=>`<div class="dot ${i<s.step?"done":i===s.step?"now":""}" title="${esc(STEPS[i-1])}"></div>`).join("");
 let rv="";if(s.review){const ch=(s.review.checks||[]);
  rv=`<div class="label">Claude's review</div>${s.review.summary?`<div class="summary">${esc(s.review.summary)}</div>`:""}
  <div class="checks">${ch.map(c=>`<span class="check ${c.ok?"pass":"fail"}" title="${esc(c.note||"")}">${c.ok?"&#10003;":"&#10007;"} ${esc(c.label)}</span>`).join("")}</div>
  ${ch.filter(c=>!c.ok&&c.note).map(c=>`<div class="failnote">${esc(c.label)}: ${esc(c.note)}</div>`).join("")}`}
 const btns=s.actions.length?`<input class="note" id="note-${esc(s.id)}" placeholder="Optional note (why, what to change)">
  <div class="btns">${s.actions.map(a=>`<button class="${GOOD.has(a)?"go":"back"}" onclick="act('${esc(s.id)}','${a}')">${LABELS[a]}</button>`).join("")}</div>`:"";
 return `<div class="card ${s.who==="you"&&s.actions.length?"you":""}"><div class="who">${s.who==="you"?"Your turn":s.who==="claude"?"Claude's turn":""}</div>
 <h3>${esc(s.title)}</h3><div class="sid">${esc(s.id)}</div><div class="steps">${dots}</div>
 <div class="status">Step ${Math.min(s.step,6)} of 6: ${esc(s.status)}</div>${facts(s)}
 ${s.images.length?`<div class="label">Pack</div>`+imgs(s.images):""}${rv}
 ${s.model_images.length?`<div class="label">Meshy previews</div>`+imgs(s.model_images):""}
 ${promptBlock(s)}${history(s)}${btns}</div>`}
function bible(b){
 if(b.status==="missing")return `<div class="bible missing"><div class="btitle">Style bible</div>
  <div class="summary">Not written yet. It is step 1: every pack review is measured against it.</div></div>`;
 TEXTS.bible=b.prompt_template||"";
 return `<div class="bible"><div class="btitle">Style bible <span class="chip ${b.status==="approved"?"ok":""}">${b.status==="approved"?"Approved":"Draft"}</span></div>
 <div class="summary">${esc(b.summary||"")}</div>${imgs(b.images)}
 ${b.prompt_template?`<div class="label">Prompt template</div><pre>${esc(b.prompt_template)}</pre><button class="mini" onclick="copy('bible')">Copy template</button>`:""}
 ${b.status!=="approved"?`<div class="btns"><button class="go" onclick="post({action:'approve_bible'})">Approve style bible</button></div>`:""}</div>`}
const STATE={approved:"approved",ready:"ready for your approval",changed:"changed since you approved",missing:"not yet"};
const SHORT={pack:"Pack",body:"Body",export:"Export",uv:"UV",texture:"Texture",rig:"Rig",ingame:"In game"};
function raceAct(race,sex,step,action){
 if(action==="undo"&&!confirm("Undo this approval?"))return;
 const note=(document.getElementById("note-"+race)||{}).value||"";
 post({action:action+"_step",race,sex,step,note})}
function sexLine(c,s){
 const track=s.steps.map(r=>`<div class="stp ${r.key===s.current?"cur":""}" title="${esc(r.label)}: ${STATE[r.state]}${r.note?' ("'+esc(r.note)+'")':""}">
  <div class="dot ${r.state}"></div>${SHORT[r.key]}</div>`).join("");
 const cur=s.steps.find(r=>r.key===s.current);
 const rows=s.steps.filter(r=>r.facts.length).map(r=>`<div class="srow"><span class="slabel">${esc(SHORT[r.key])}</span>${
  r.facts.map(f=>`<span class="fact ${f.kind}">${esc(f.text)}</span>`).join("")}</div>`).join("");
 const btns=[];
 if(cur&&(cur.state==="ready"||cur.state==="changed"))
  btns.push(`<button class="go" onclick="raceAct('${c.id}','${s.sex}','${cur.key}','approve')">Approve: ${esc(cur.label)}</button>`);
 if(s.undo){const u=s.steps.find(r=>r.key===s.undo);
  btns.push(`<button class="mini back" onclick="raceAct('${c.id}','${s.sex}','${s.undo}','undo')">Undo: ${esc(u.label)}</button>`)}
 const render=s.render?`<img class="render" src="${url("board_cache/"+s.render)}" onclick="zoom('${url("board_cache/"+s.render)}')" title="Front view of the export">`:"";
 return `<div class="sexline"><div class="sexmain"><div class="sexname">${s.sex==="male"?"Male":"Female"}</div>
  <div class="track">${track}</div><div class="status ${s.who}">${esc(s.status)}</div>${rows}
  ${btns.length?`<div class="btns">${btns.join("")}</div>`:""}</div>${render}</div>`}
let showDiscarded=new Set();
function sheetAct(path,action,name){
 if(action==="use_sheet"&&!confirm(`Make this the ${name} sheet in ref_art? A sheet already there moves to ref_art/_replaced.`))return;
 post({action,path})}
function sheetCands(owner,name,tasks){
 const all=tasks.flatMap(t=>t.images.length?t.images.map(i=>({t,i})):[{t,i:null}]);
 if(!all.length)return "";
 const hidden=all.filter(x=>x.i&&x.i.state==="discarded").length,show=showDiscarded.has(owner);
 const rows=all.filter(x=>show||!x.i||x.i.state!=="discarded").map(({t,i})=>{
  const key="s:"+t.task;TEXTS[key]=t.prompt||"";
  const meta=`<div><b>${esc(t.created)}</b> &middot; ${esc(t.ai_model||"?")} &middot; ${t.credits??"?"} credits${t.estimated?" (estimate)":""}
   &middot; ${t.type==="image-to-image"?(t.references.length?"from "+esc(t.references.join(", ")):"from task "+esc(t.input_task_id)):"from text"}</div>
   ${t.prompt?`<details><summary>Prompt</summary><pre>${esc(t.prompt)}</pre><button class="mini" onclick="copy('${key}')">Copy prompt</button></details>`:""}`;
  if(!i)return `<div class="cand"><div class="cmeta"><span class="badge">Not downloaded</span>Made, not saved yet: ask Claude to download task ${esc(t.task)}.${meta}</div></div>`;
  const p=esc(i.path),badge=i.state==="used"?`<span class="badge used">In use</span>`:i.state==="new"?`<span class="badge">New</span>`:`<span class="badge">Discarded</span>`;
  const btns=i.state==="discarded"?`<button class="mini" onclick="sheetAct('${p}','restore_sheet')">Restore</button>`:
   `${i.state!=="used"?`<button class="mini go" onclick="sheetAct('${p}','use_sheet','${esc(name)}')">Use this</button>`:""}
    ${i.state!=="used"?`<button class="mini back" onclick="sheetAct('${p}','discard_sheet')">Discard</button>`:""}`;
  return `<div class="cand ${i.state}"><img src="${url(i.path)}" loading="lazy" onclick="zoom('${url(i.path)}')" title="${p}">
   <div class="cmeta">${badge}${meta}<div class="btns">${btns}</div></div></div>`}).join("");
 const tog=hidden?`<button class="mini" onclick="showDiscarded.${show?"delete":"add"}('${esc(owner)}');load(true)">${show?"Hide":"Show"} ${hidden} discarded</button>`:"";
 return `<div class="label">Generated sheets</div><div class="cands">${rows}</div>${tog}`}
function spendFact(x){return x.spend?`<div class="facts"><span class="fact">Credits used: ${x.spend.credits}${x.spend.estimated?" (estimate)":""}</span></div>`:""}
function otherCard(o){
 const pack=o.pack?`<img class="packthumb" src="${url("ref_art/"+o.pack)}" onclick="zoom('${url("ref_art/"+o.pack)}')" title="${esc(o.pack)}">`:"";
 const fresh=o.candidates.some(t=>t.images.some(i=>i.state==="new"));
 return `<div class="card race ${fresh?"you":""}"><div class="who">${fresh?"Your turn":""}</div>
  <div class="rhead"><div><h3>${esc(o.name)}</h3><div class="sid">${o.pack?esc(o.pack):"no sheet in ref_art yet"}</div></div>${pack}</div>
  ${spendFact(o)}${sheetCands(o.id,o.name,o.candidates)}</div>`}
function raceCard(c){
 const you=c.sexes.some(s=>s.who==="you");
 const pack=c.pack?`<img class="packthumb" src="${url("ref_art/"+c.pack)}" onclick="zoom('${url("ref_art/"+c.pack)}')" title="${esc(c.pack)}">`:"";
 return `<div class="card race ${you?"you":""}"><div class="who">${you?"Your turn":""}</div>
  <div class="rhead"><div><h3>${esc(c.name)}</h3><div class="sid">${c.lo.toFixed(2)} to ${c.hi.toFixed(2)} m${c.checking?" &middot; reading the .blend...":""}</div></div>${pack}</div>
  ${spendFact(c)}${c.sexes.map(s=>sexLine(c,s)).join("")}${sheetCands(c.id,c.name.replace(/[^A-Za-z0-9]/g,""),c.candidates)}
  <input class="note" id="note-${c.id}" placeholder="Optional note to keep with an approval">${history(c)}</div>`}
function lineup(races){
 const list=[];races.forEach(c=>c.sexes.forEach(s=>{if(s.render&&s.height)list.push({name:c.name,sex:s.sex,img:"board_cache/"+s.render,h:s.height,lo:c.lo,hi:c.hi,done:s.done})}));
 if(!list.length)return `<div class="empty">No exports yet. Each exported model appears here, rendered at its measured height.</div>`;
 list.sort((a,b)=>a.h-b.h);
 const max=Math.max(...list.map(s=>s.h)),H=300,L=50;
 let r="";for(let m=0.5;m<=max+0.001;m+=0.5)r+=`<div class="rline" style="bottom:${L+m/max*H}px"><span>${m.toFixed(1)} m</span></div>`;
 const figs=list.map(s=>`<div class="fig"><img src="${url(s.img)}" style="height:${s.h/max*H}px" onclick="zoom('${url(s.img)}')" title="${esc(s.name)}, ${s.sex}">
  <div class="fl">${esc(s.name)} ${s.sex==="male"?"&#9794;":"&#9792;"}</div><div class="fh">${s.h.toFixed(2)} m</div></div>`).join("");
 const w=60+list.length*120;
 return `<div class="lineup"><div class="stage" style="height:${H+L+20}px"><div style="position:relative;height:100%;min-width:${w}px">${r}<div class="figs">${figs}</div></div></div>
 <div class="hint">Every export, rendered from the front and drawn at its measured height: the check that keeps sixteen races in proportion.</div></div>`}
function sections(list,bySid){
 return list.map(s=>{const pct=s.total?Math.round(100*s.done/s.total):0;
  const rows=s.items.map(i=>{const st=i.subject&&bySid[i.subject];
   return `<div class="row"><span class="box ${i.done?"on":""}"></span>
   <span>${esc(i.text)}</span>${i.group?`<span class="grp">${esc(i.group)}</span>`:""}
   ${st&&!i.done&&st.pill?`<span class="pill">${esc(st.pill)}</span>`:""}</div>`}).join("");
  return `<details class="sec" data-n="${s.num}" ${openSecs.has(s.num)?"open":""} ontoggle="t(this)">
  <summary><span class="name">${s.num}. ${esc(s.title)}</span><span class="bar"><span class="fill" style="width:${pct}%;display:block"></span></span>
  <span class="count">${s.done} / ${s.total}</span></summary><div class="rows">${rows}</div></details>`}).join("")}
function t(el){const n=+el.dataset.n;el.open?openSecs.add(n):openSecs.delete(n)}
async function load(force){
 const a=document.activeElement;
 if(!force&&a&&["INPUT","TEXTAREA","SELECT"].includes(a.tagName)){clearTimeout(TIMER);TIMER=setTimeout(load,5000);return}
 const d=await (await fetch("/api/state")).json();STEPS=d.steps;
 const c=d.credits;
 document.getElementById("credits").textContent=c.balance==null?"Credits: not checked yet":`Credits: ${Number(c.balance).toLocaleString()}`+
  (c.checked_at?` (as of ${when(c.checked_at)})`:"");
 document.getElementById("spent").textContent=`Spent on art: ${c.spent} credits`;
 const te_=document.getElementById("trip");
 if(c.tripwire){te_.className="chip bad";te_.textContent=`TRIPWIRE SET: a task cost ${c.tripwire.consumed??"?"}, expected ${c.tripwire.expected??"?"}. Paid calls blocked.`}
 else{te_.className="chip ok";te_.textContent="Tripwire: clear"}
 const done=d.sections.reduce((x,s)=>x+s.done,0),tot=d.sections.reduce((x,s)=>x+s.total,0);
 document.getElementById("overall").textContent=`Checklist: ${done} / ${tot}`;
 const lines=d.races.flatMap(c=>c.sexes);
 document.getElementById("ingame").textContent=`Bodies in the game: ${lines.filter(s=>s.done).length} / ${lines.length}`;
 const w=d.worker,wc=document.getElementById("worker");
 if(!w.blender){wc.className="chip bad";wc.textContent="Blender not found: set PD_BLENDER"}
 else if(w.busy||w.waiting){wc.className="chip";wc.textContent=`Blender: ${w.busy||"starting"}${w.waiting>1?` (${w.waiting-1} more waiting)`:""}`}
 else if(w.error){wc.className="chip bad";wc.textContent="Blender: "+w.error}
 else{wc.className="chip ok";wc.textContent="Blender: idle"}
 document.getElementById("demochip").outerHTML=d.demo?`<span id="demochip" class="chip demochip">DEMO</span>`:`<span id="demochip"></span>`;
 document.getElementById("demo").innerHTML=d.demo?`<div class="demo">Demo: the race cards read your real model files, but approvals, checklist ticks and renders go to a throwaway folder, and the Meshy cards are samples. Every button works here and changes nothing real.</div>`:"";
 const fresh=c=>(c.candidates||[]).some(t=>t.images.some(i=>i.state==="new"));
 const st=c=>c.sexes.every(s=>s.done)?"done":(c.sexes.some(s=>s.who==="you")||fresh(c))?"you":
  (c.sexes.some(s=>s.steps.some(r=>r.state!=="missing"))||(c.candidates||[]).length)?"progress":"later";
 const group=k=>d.races.filter(c=>st(c)===k);
 const yours=group("you"),prog=group("progress"),fin=group("done"),later=group("later");
 document.getElementById("yours").innerHTML=yours.length?yours.map(raceCard).join(""):`<div class="empty">Nothing waiting on you.</div>`;
 document.getElementById("progress").innerHTML=prog.length?prog.map(raceCard).join(""):`<div class="empty">Nothing else in progress.</div>`;
 document.getElementById("donewrap").innerHTML=fin.length?`<h2>Done</h2><div class="cards">${fin.map(raceCard).join("")}</div>`:"";
 document.getElementById("notstarted").innerHTML=later.length?`<div class="later">${later.map(c=>`<span class="chip" title="${esc(c.sexes[0].status)}">${esc(c.name)}</span>`).join("")}</div>
  <div class="hint">Nothing found for these yet. A race moves up once its ModelPack sheet is in F:/Projects/ref_art, or Meshy has made a candidate sheet for it.</div>`:`<div class="empty">Every race has started.</div>`;
 document.getElementById("lineup").innerHTML=lineup(d.races);
 document.getElementById("others").innerHTML=d.others.length?d.others.map(otherCard).join(""):
  `<div class="empty">No other sheets. Props, stations and mobs appear here once a ModelPack sheet or a Meshy candidate exists for them.</div>`;
 // checklist pills: where each race/sex row stands (the race workflow wins over an old Meshy card)
 const by={};d.subjects.forEach(s=>{if(s.step>2)by[s.id]={pill:"Meshy step "+s.step}});
 d.races.forEach(c=>c.sexes.forEach(s=>{const cur=s.steps.find(r=>r.key===s.current);
  if(cur&&s.steps.some(r=>r.state!=="missing"))by[c.id+"/"+s.sex]={pill:"at: "+cur.label}}));
 document.getElementById("sections").innerHTML=sections(d.sections,by);
 document.getElementById("bible").innerHTML=bible(d.bible);
 document.getElementById("meshycards").innerHTML=d.subjects.length?d.subjects.map(card).join(""):`<div class="empty">No concept-art cards.</div>`;
 document.getElementById("meshycount").textContent=`${d.subjects.length} cards`;
 clearTimeout(TIMER);TIMER=setTimeout(load,(w.busy||w.waiting)?4000:15000)}
let TIMER=null;load(true);
</script></body></html>"""


if __name__ == "__main__":
    main()
