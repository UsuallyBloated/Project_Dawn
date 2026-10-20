"""Model sheets made by Meshy's 2D tools, as the Art Board shows them.

The Meshy client (.claude/hooks/meshy_client.py) logs every image task in its ledger with the
subject, prompt, model and reference file names; its download tool saves the images to
Project_Dawn_Source/meshy_downloads/<subject>/<task>/image_N.png. This module turns those into
candidates on the board: a race's candidates sit on its card, any other subject's (Blacksmithing,
later props and mobs) under "Other sheets". "Use this" copies a candidate into F:\\Projects\\ref_art
as ModelPack_<Name>.<ext>, where the race workflow's pack step finds it; a sheet it replaces is
moved to ref_art/_replaced/ with a timestamp, never overwritten. "Discard" only hides a candidate.

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
TASK_LEDGER = ""
DECISIONS = os.path.join(race_progress.BOARD_DATA, "sheets.json")


def _load(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


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


def _task_dir(subject: str, task: str) -> str | None:
    """Where a task's images were saved. The download folder is meant to be the subject; any
    first-level folder holding the task is accepted, in case it was saved under another name."""
    preferred = os.path.join(DOWNLOAD_ROOT, subject, task)
    if os.path.isdir(preferred):
        return preferred
    if os.path.isdir(DOWNLOAD_ROOT):
        for folder in os.listdir(DOWNLOAD_ROOT):
            d = os.path.join(DOWNLOAD_ROOT, folder, task)
            if os.path.isdir(d):
                return d
    return None


def candidates() -> dict:
    """Subject to its image tasks, newest first; each task lists its saved images."""
    ledger, decisions = _load(TASK_LEDGER), _load(DECISIONS)
    out = {}
    for task, entry in ledger.items():
        subject = entry.get("subject", "")
        if entry.get("type") not in IMAGE_TASK_TYPES or not SUBJECT_RE.match(subject) or not TASK_RE.match(task):
            continue
        d = _task_dir(subject, task)
        files = sorted(n for n in os.listdir(d) if FILE_RE.match(n)) if d else []
        rel_dir = os.path.relpath(d, DOWNLOAD_ROOT).replace(os.sep, "/") if d else ""
        images = []
        for n in files:
            rel = f"meshy_downloads/{rel_dir}/{n}"
            images.append({"path": rel, "state": (decisions.get(rel) or {}).get("state", "new")})
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
    if len(parts) != 4 or parts[0] != "meshy_downloads" or not FILE_RE.match(parts[3]) or not TASK_RE.match(parts[2]):
        raise ValueError("not a sheet candidate")
    entry = _load(TASK_LEDGER).get(parts[2]) or {}
    subject = entry.get("subject", "")
    if entry.get("type") not in IMAGE_TASK_TYPES or not SUBJECT_RE.match(subject):
        raise ValueError("that image is not from one of our image tasks")
    root = os.path.realpath(DOWNLOAD_ROOT)
    real = os.path.realpath(os.path.join(root, parts[1], parts[2], parts[3]))
    if os.path.commonpath([real, root]) != root or not os.path.isfile(real):
        raise ValueError("that image is not there")
    return subject, parts[2], real


def use(rel: str, races: dict) -> str:
    """Make a candidate the subject's model sheet in ref_art, moving any sheet it replaces aside."""
    subject, _task, src = _resolve(rel)
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
    decisions = _load(DECISIONS)
    for key, rec in decisions.items():  # only one candidate per subject is "in use"
        if rec.get("state") == "used" and rec.get("subject") == subject:
            rec["state"] = "new"
    decisions[rel] = {"state": "used", "subject": subject, "at": time.time()}
    _save_decisions(decisions)
    return f"Now the {name} sheet: {os.path.basename(target)}.{moved}"


def set_state(rel: str, state: str) -> str:
    subject, _task, _src = _resolve(rel)
    decisions = _load(DECISIONS)
    if (decisions.get(rel) or {}).get("state") == "used" and state == "discarded":
        raise ValueError("this one is the sheet in use; use another before discarding it")
    decisions[rel] = {"state": state, "subject": subject, "at": time.time()}
    _save_decisions(decisions)
    return "Discarded (hidden; Restore brings it back)." if state == "discarded" else "Restored."
