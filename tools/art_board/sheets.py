"""Model sheets made by Meshy's 2D tools, as the Art Board shows them.

The Meshy client (.claude/hooks/meshy_client.py) logs every image task in its ledger with the
subject, prompt, model and reference file names; its download tool saves the images to
Project_Dawn_Source/meshy_downloads/<subject>/<task>/image_N.png. This module turns those into
candidates on the board: a race's candidates sit on its card, any other subject's (Blacksmithing,
later props and mobs) under "Other sheets". "Use this" copies a candidate into F:\\Projects\\ref_art
as ModelPack_<Name>.<ext>, where the race workflow's pack step finds it; a sheet it replaces is
moved to ref_art/_replaced/ with a timestamp, never overwritten. "Discard" moves the image to
Project_Dawn_Source/discarded/<subject>/<task>/ (one folder per race; user, 2026-10-23), and
"Restore" moves it back to meshy_downloads.

Read-only toward Meshy: nothing here calls the API or touches the key. Decisions live in
Project_Dawn_Source/art_board/sheets.json (not in git).
"""

import json
import os
import re
import shutil
import time

import race_progress

IMAGE_TASK_TYPES = ("text-to-image", "image-to-image")
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp")
REPLACED_DIR = "_replaced"
SUBJECT_RE = re.compile(r"^[a-z0-9_-]{1,48}$")
TASK_RE = re.compile(r"^[0-9A-Za-z-]{8,64}$")
FILE_RE = re.compile(r"^image_\d{1,2}\.(png|jpe?g|webp)$")

# Set by art_board.py (the demo points them at a sandbox).
DOWNLOAD_ROOT = ""
DISCARD_ROOT = ""
TASK_LEDGER = ""
DECISIONS = os.path.join(race_progress.BOARD_DATA, "sheets.json")


def _load(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def _key(task: str, name: str) -> str:
    """A decision's key: the task and the file, so it survives the image moving between folders."""
    return f"{task}/{name}"


def _load_decisions() -> dict:
    """The decisions, with any older path-keyed entry (meshy_downloads/<s>/<task>/<file>) rekeyed."""
    out = {}
    for k, rec in _load(DECISIONS).items():
        parts = k.split("/")
        out[_key(parts[-2], parts[-1]) if len(parts) == 4 else k] = rec
    return out


def _save_decisions(data: dict) -> None:
    os.makedirs(os.path.dirname(DECISIONS), exist_ok=True)
    tmp = DECISIONS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, DECISIONS)


def pack_key(name: str) -> str:
    """The key race_progress.find_packs uses: the race id with underscores dropped."""
    return race_progress.race_id(name).replace("_", "")


def sheet_name(subject: str, races: dict) -> str:
    """The <Name> in ModelPack_<Name>: a race's name with its punctuation and spaces dropped
    (DarkElf, HalfOgre, Kelvarath, the style find_packs reads), else the subject in title case."""
    if subject in races:
        return re.sub(r"[^A-Za-z0-9]", "", races[subject])
    return "".join(part.capitalize() for part in re.split(r"[_-]+", subject) if part)


def all_packs() -> dict:
    """Pack key to path for every ModelPack_* sheet at the top of ref_art (the _replaced folder is
    not read, so a replaced sheet never comes back as a pack)."""
    packs, ref = {}, race_progress.REF_ART
    if os.path.isdir(ref):
        for n in sorted(os.listdir(ref)):
            m = race_progress.PACK_RE.match(n)
            if m and os.path.isfile(os.path.join(ref, n)):
                packs[pack_key(m.group(1))] = os.path.join(ref, n)
    return packs


ROOT_NAMES = ("meshy_downloads", "discarded")


def _roots() -> dict:
    return {"meshy_downloads": DOWNLOAD_ROOT, "discarded": DISCARD_ROOT}


def _task_dirs(subject: str, task: str) -> list:
    """(root name, folder) for every place a task's images sit: its download folder (meant to be
    the subject; any first-level folder holding the task is accepted, in case it was saved under
    another name) and its discard folder."""
    found = []
    for name, root in _roots().items():
        if not root or not os.path.isdir(root):
            continue
        d = os.path.join(root, subject, task)
        if not os.path.isdir(d):
            d = next((os.path.join(root, f, task) for f in os.listdir(root)
                      if os.path.isdir(os.path.join(root, f, task))), None)
        if d:
            found.append((name, d))
    return found


def candidates() -> dict:
    """Subject to its image tasks, newest first; each task lists its saved images."""
    ledger, decisions = _load(TASK_LEDGER), _load_decisions()
    out = {}
    for task, entry in ledger.items():
        subject = entry.get("subject", "")
        if entry.get("type") not in IMAGE_TASK_TYPES or not SUBJECT_RE.match(subject) or not TASK_RE.match(task):
            continue
        images = []
        for root_name, d in _task_dirs(subject, task):
            rel_dir = os.path.relpath(d, _roots()[root_name]).replace(os.sep, "/")
            for n in sorted(n for n in os.listdir(d) if FILE_RE.match(n)):
                images.append({"path": f"{root_name}/{rel_dir}/{n}",
                               "state": (decisions.get(_key(task, n)) or {}).get("state", "new")})
        out.setdefault(subject, []).append({
            "task": task, "type": entry["type"], "created": entry.get("created", ""),
            "prompt": entry.get("prompt", ""), "ai_model": entry.get("ai_model", ""),
            "aspect_ratio": entry.get("aspect_ratio", ""), "references": entry.get("references", []),
            "input_task_id": entry.get("input_task_id", ""),
            "credits": entry.get("consumed", entry.get("expected")),
            "estimated": "consumed" not in entry, "images": images})
    for tasks in out.values():
        tasks.sort(key=lambda t: t["created"], reverse=True)
    return out


def other_sheets(race_ids: set, cands: dict) -> list:
    """Sheets and candidates that belong to no race: one entry per subject."""
    race_keys = {r.replace("_", "") for r in race_ids}
    packs = {k: p for k, p in all_packs().items() if k not in race_keys}
    subjects = {s for s in cands if s not in race_ids}
    by_key = {pack_key(s): s for s in subjects}
    out = []
    for key in sorted(set(packs) | set(by_key)):
        subject = by_key.get(key, key)
        out.append({"id": subject, "name": sheet_name(subject, {}),
                    "pack": os.path.basename(packs[key]) if key in packs else None,
                    "candidates": cands.get(subject, [])})
    return out


def _resolve(rel: str) -> tuple:
    """(subject, task, absolute path) for a candidate image the ledger vouches for, or raise."""
    parts = rel.split("/")
    if (len(parts) != 4 or parts[0] not in ROOT_NAMES or not SUBJECT_RE.match(parts[1])
            or not TASK_RE.match(parts[2]) or not FILE_RE.match(parts[3])):
        raise ValueError("not a sheet candidate")
    entry = _load(TASK_LEDGER).get(parts[2]) or {}
    subject = entry.get("subject", "")
    if entry.get("type") not in IMAGE_TASK_TYPES or not SUBJECT_RE.match(subject):
        raise ValueError("that image is not from one of our image tasks")
    root = os.path.realpath(_roots()[parts[0]])
    real = os.path.realpath(os.path.join(root, parts[1], parts[2], parts[3]))
    if os.path.commonpath([real, root]) != root or not os.path.isfile(real):
        raise ValueError("that image is not there")
    return subject, parts[2], real


def use(rel: str, races: dict) -> str:
    """Make a candidate the subject's model sheet in ref_art, moving any sheet it replaces aside."""
    subject, task, src = _resolve(rel)
    if rel.startswith("discarded/"):
        raise ValueError("restore this one before using it")
    name = sheet_name(subject, races)
    ref = race_progress.REF_ART
    os.makedirs(ref, exist_ok=True)
    moved = ""
    old = all_packs().get(pack_key(subject if subject not in races else races[subject]))
    if old:
        aside = os.path.join(ref, REPLACED_DIR)
        os.makedirs(aside, exist_ok=True)
        base, ext = os.path.splitext(os.path.basename(old))
        dest = os.path.join(aside, f"{base}_{time.strftime('%Y%m%d_%H%M%S')}{ext}")
        shutil.move(old, dest)
        moved = f" The old sheet is in ref_art/{REPLACED_DIR}/{os.path.basename(dest)}."
    target = os.path.join(ref, f"ModelPack_{name}{os.path.splitext(src)[1].lower()}")
    shutil.copy2(src, target)
    os.utime(target)  # a fresh mtime, so an approved pack step shows "changed"
    decisions = _load_decisions()
    for key, rec in decisions.items():  # only one candidate per subject is "in use"
        if rec.get("state") == "used" and rec.get("subject") == subject:
            rec["state"] = "new"
    decisions[_key(task, os.path.basename(src))] = {"state": "used", "subject": subject, "at": time.time()}
    _save_decisions(decisions)
    return f"Now the {name} sheet: {os.path.basename(target)}.{moved}"


def _move_image(src: str, subject: str, task: str, to_root: str) -> str:
    """Move one image into <to_root>/<subject>/<task>/, dropping the old task folder if emptied."""
    dest_dir = os.path.join(to_root, subject, task)
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, os.path.basename(src))
    if os.path.realpath(src) != os.path.realpath(dest):
        if os.path.exists(dest):
            raise ValueError("an image of that name is already there")
        shutil.move(src, dest)
        try:
            os.rmdir(os.path.dirname(src))
        except OSError:
            pass
    return dest


def set_state(rel: str, state: str) -> str:
    """Discard moves the image to the discard folder for its race; Restore moves it back."""
    subject, task, src = _resolve(rel)
    name = os.path.basename(src)
    decisions = _load_decisions()
    if (decisions.get(_key(task, name)) or {}).get("state") == "used" and state == "discarded":
        raise ValueError("this one is the sheet in use; use another before discarding it")
    if not DISCARD_ROOT:
        raise ValueError("no discard folder is set")
    _move_image(src, subject, task, DISCARD_ROOT if state == "discarded" else DOWNLOAD_ROOT)
    decisions[_key(task, name)] = {"state": state, "subject": subject, "at": time.time()}
    _save_decisions(decisions)
    if state == "discarded":
        return f"Discarded: moved to discarded/{subject}/ (Restore brings it back)."
    return "Restored."


def sweep_discards() -> int:
    """Move any image marked discarded that still sits in meshy_downloads (an older discard) into
    its race's discard folder, and save the decisions in their task/file form. Returns how many
    moved."""
    if not DISCARD_ROOT or not os.path.isdir(DOWNLOAD_ROOT):
        return 0
    decisions, ledger, moved = _load_decisions(), _load(TASK_LEDGER), 0
    for key, rec in decisions.items():
        if rec.get("state") != "discarded" or "/" not in key:
            continue
        task, name = key.split("/", 1)
        subject = (ledger.get(task) or {}).get("subject", rec.get("subject", ""))
        if not SUBJECT_RE.match(subject or "") or not TASK_RE.match(task) or not FILE_RE.match(name):
            continue
        for root_name, d in _task_dirs(subject, task):
            src = os.path.join(d, name)
            if root_name == "meshy_downloads" and os.path.isfile(src):
                _move_image(src, subject, task, DISCARD_ROOT)
                moved += 1
    if os.path.exists(DECISIONS):
        _save_decisions(decisions)
    return moved
