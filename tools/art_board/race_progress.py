"""The character-model workflow behind the Art Board's race cards.

One card per playable race (creature_heights.md's table), with a male and a female line. Each line
walks seven steps, and every step is detected from the files, then approved by the user:

  pack     ModelPack_<Race>.png in F:/Projects/ref_art (one sheet holds both sexes)
  body     the race's .blend holds meshes in a collection named for the sex ("GnomeMale")
  export   <race>.glb or <race>_male.glb / <race>_female.glb beside the .blend: height, triangles, facing
  uv       the export's UVs are a real unwrap (glb_checks.py)
  texture  the export carries a texture
  rig      the export carries a skeleton
  ingame   race_model.gd mounts a GLB that is byte-identical to this export

Approvals live in Project_Dawn_Source/art_board/progress.json with a fingerprint of the file they
approved, so a step whose file changes afterwards shows as changed. Looking inside a .blend and
rendering the lineup need Blender; a background worker does both and caches the results in
Project_Dawn_Source/art_board/cache/, opening a .blend again only after it has been saved.
"""

import hashlib
import json
import os
import queue
import re
import subprocess
import threading
import time

import glb_checks
import measure_glb

BOARD_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(BOARD_DIR))
SOURCE_ROOT = os.path.join(os.path.dirname(REPO_ROOT), "Project_Dawn_Source")
REF_ART = os.path.join(os.path.dirname(REPO_ROOT), "ref_art")
MODELS_ROOT = os.path.join(SOURCE_ROOT, "models", "characters")
RACE_MODEL_GD = os.path.join(REPO_ROOT, "scripts", "race_model.gd")
HEIGHTS_DOC = os.path.join(REPO_ROOT, "docs", "reference", "creature_heights.md")
BOARD_DATA = os.path.join(SOURCE_ROOT, "art_board")
PROGRESS = os.path.join(BOARD_DATA, "progress.json")
CACHE_DIR = os.path.join(BOARD_DATA, "cache")
BLENDER = os.environ.get("PD_BLENDER", r"D:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe")
BLENDER_SCRIPT = os.path.join(BOARD_DIR, "blender_board.py")

SEXES = ("male", "female")
STEPS = [("pack", "Model pack"), ("body", "Body built"), ("export", "Exported"), ("uv", "UV unwrap"),
         ("texture", "Texture"), ("rig", "Rig"), ("ingame", "In game")]
STEP_KEYS = [k for k, _ in STEPS]
LABELS = dict(STEPS)
HEIGHT_TOLERANCE = 0.02
RENDER_PX = 400
PACK_RE = re.compile(r"^ModelPack_(.+)\.(png|jpe?g|webp)$", re.IGNORECASE)
HEIGHT_ROW_RE = re.compile(r"^\|\s*\*\*(.+?)\*\*\s*\|\s*([\d.]+)\s*[–-]\s*([\d.]+)\s*\|")
MODELS_ENTRY_RE = re.compile(r'^\s*"([^"]+)":\s*\{(.*?)^\s*\},', re.MULTILINE | re.DOTALL)
SCENE_RE = re.compile(r'"scene":\s*"res://([^"]+)"')


def race_id(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("`", "").replace("'", "")).strip("_")


def read_races() -> list:
    """(id, name, low m, high m) for every playable race, in the order of creature_heights.md."""
    races, inside = [], False
    try:
        with open(HEIGHTS_DOC, encoding="utf-8") as f:
            for line in f:
                if line.startswith("## "):
                    inside = "Playable Race Heights" in line
                    continue
                m = HEIGHT_ROW_RE.match(line) if inside else None
                if m:
                    races.append((race_id(m.group(1)), m.group(1).replace("\\", ""),
                                  float(m.group(2)), float(m.group(3))))
    except FileNotFoundError:
        pass
    return races


# ------------------------------------------------------------------- files

def fingerprint(path: str) -> str | None:
    """Size and modification time; changes whenever the file is saved again."""
    try:
        st = os.stat(path)
    except OSError:
        return None
    return f"{st.st_size}:{st.st_mtime_ns}"


def race_files(rid: str) -> dict:
    folder = os.path.join(MODELS_ROOT, rid)
    base = rid.replace("_", "")
    male = next((os.path.join(folder, n) for n in (base + "_male.glb", base + ".glb")
                 if os.path.isfile(os.path.join(folder, n))), os.path.join(folder, base + ".glb"))
    return {"folder": folder, "blend": os.path.join(folder, base + ".blend"),
            "export": {"male": male, "female": os.path.join(folder, base + "_female.glb")}}


def find_packs() -> dict:
    """Race id (underscores dropped, so DarkElf finds dark_elf) to the pack image's path."""
    packs = {}
    if os.path.isdir(REF_ART):
        for n in sorted(os.listdir(REF_ART)):
            m = PACK_RE.match(n)
            if m:
                packs[race_id(m.group(1)).replace("_", "")] = os.path.join(REF_ART, n)
    return packs


def mounted_models() -> dict:
    """Race id to the absolute path of the GLB race_model.gd's MODELS table mounts."""
    try:
        with open(RACE_MODEL_GD, encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        return {}
    block = text[text.find("const MODELS"):]
    out = {}
    for name, body in MODELS_ENTRY_RE.findall(block):
        m = SCENE_RE.search(body)
        if m:
            out[race_id(name)] = os.path.join(REPO_ROOT, *m.group(1).split("/"))
    return out


_hash_cache, _check_cache = {}, {}


def file_hash(path: str) -> str | None:
    fp = fingerprint(path)
    if fp is None:
        return None
    key = (path, fp)
    if key not in _hash_cache:
        with open(path, "rb") as f:
            _hash_cache[key] = hashlib.sha1(f.read()).hexdigest()
    return _hash_cache[key]


def glb_findings(path: str) -> dict | None:
    fp = fingerprint(path)
    if fp is None:
        return None
    key = (path, fp)
    if key not in _check_cache:
        try:
            _check_cache[key] = glb_checks.check(path)
        except Exception as exc:  # a half-written or unusual file must not break the board
            _check_cache[key] = {"error": str(exc)}
    return _check_cache[key]


# ------------------------------------------------------- blender worker

_jobs: "queue.Queue[tuple]" = queue.Queue()
_queued, _failed, _lock, _worker = set(), set(), threading.Lock(), None
_status = {"busy": "", "error": ""}


def _cache_json(name: str) -> dict:
    try:
        with open(os.path.join(CACHE_DIR, name), encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def _run_blender(args: list) -> None:
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    subprocess.run([BLENDER, "--background", "--factory-startup", "--disable-autoexec",
                    "--python", BLENDER_SCRIPT, "--"] + args,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=300,
                   creationflags=flags, check=False)


def _work() -> None:
    while True:
        job = _jobs.get()
        kind, src, fp, out = job
        _status["busy"] = f"{'Reading' if kind == 'scan' else 'Rendering'} {os.path.basename(src)}"
        try:
            os.makedirs(CACHE_DIR, exist_ok=True)
            tmp = out + ".tmp" + (".png" if kind == "render" else "")
            if kind == "scan":
                _run_blender(["scan", src, tmp])
                with open(tmp, encoding="utf-8") as f:
                    result = json.load(f)
                os.remove(tmp)
                with open(out, "w", encoding="utf-8") as f:
                    json.dump({"fp": fp, "result": result}, f)
            else:
                _run_blender(["render", src, tmp, str(RENDER_PX)])
                if os.path.isfile(tmp):
                    os.replace(tmp, out)
                    stem = os.path.basename(out).rsplit("_", 1)[0]
                    for old in os.listdir(CACHE_DIR):  # drop renders of earlier exports
                        if old.startswith(stem + "_") and old.endswith(".png") and old != os.path.basename(out):
                            os.remove(os.path.join(CACHE_DIR, old))
            _status["error"] = ""
        except Exception as exc:
            # remembered until the file changes (a new fingerprint makes a new job), so one
            # unreadable file is not reopened in Blender on every refresh
            with _lock:
                _failed.add(job)
            _status["error"] = f"{os.path.basename(src)}: {exc}"
        finally:
            with _lock:
                _queued.discard(job)
            _status["busy"] = ""


def _enqueue(job: tuple) -> None:
    global _worker
    if not os.path.isfile(BLENDER):
        return
    with _lock:
        if job in _queued or job in _failed:
            return
        _queued.add(job)
        if _worker is None:
            _worker = threading.Thread(target=_work, daemon=True)
            _worker.start()
    _jobs.put(job)


def worker_status() -> dict:
    with _lock:
        waiting = len(_queued)
    return {"busy": _status["busy"], "waiting": waiting, "error": _status["error"],
            "blender": os.path.isfile(BLENDER), "blender_path": BLENDER}


def blend_scan(rid: str, blend: str) -> tuple:
    """(result or None, checking?) for a race's .blend, queueing a fresh scan when it changed."""
    fp = fingerprint(blend)
    if fp is None:
        return None, False
    out = os.path.join(CACHE_DIR, f"scan_{rid}.json")
    cached = _cache_json(f"scan_{rid}.json")
    if cached.get("fp") != fp:
        _enqueue(("scan", blend, fp, out))
        return cached.get("result"), True
    return cached.get("result"), False


def render_for(rid: str, sex: str, glb: str) -> str | None:
    """Cache-relative name of the export's front render, queueing one when it is missing."""
    fp = fingerprint(glb)
    if fp is None:
        return None
    name = f"render_{rid}_{sex}_{hashlib.sha1(fp.encode()).hexdigest()[:10]}.png"
    if os.path.isfile(os.path.join(CACHE_DIR, name)):
        return name
    _enqueue(("render", glb, fp, os.path.join(CACHE_DIR, name)))
    return None


# ------------------------------------------------------------- approvals

def load_progress() -> dict:
    try:
        with open(PROGRESS, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_progress(data: dict) -> None:
    os.makedirs(os.path.dirname(PROGRESS), exist_ok=True)
    tmp = PROGRESS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, PROGRESS)


# ------------------------------------------------------------- detection

def _fact(text: str, kind: str = "") -> dict:
    return {"text": text, "kind": kind}


def detect(rid: str, name: str, lo: float, hi: float, packs: dict, mounted: dict) -> dict:
    """Each step's detection for both sexes: ready (bool), facts, hint, fingerprint."""
    files = race_files(rid)
    base = rid.replace("_", "")
    pack = packs.get(rid.replace("_", ""))
    scan, checking = blend_scan(rid, files["blend"])
    blender_ok = os.path.isfile(BLENDER)
    out = {"pack": pack, "checking": checking, "sexes": {}}

    for sex in SEXES:
        steps = {}
        steps["pack"] = {"ready": bool(pack), "fp": fingerprint(pack) if pack else None,
                         "facts": [_fact(os.path.basename(pack))] if pack else [],
                         "hint": f"Make the {name} model pack and save it as F:/Projects/ref_art/ModelPack_{name.replace('`', '').replace(' ', '')}.png."}

        count = (scan or {}).get(sex, 0)
        facts = []
        if scan:
            colls = [c for c in (scan.get("collections") or {}) if (sex == "female") == ("female" in c.lower())
                     and "male" in c.lower()]
            if count:
                facts.append(_fact(f"{count} meshes in {', '.join(colls) or 'the file'}"))
            if scan.get("untagged") and sex == "male":
                facts.append(_fact(f"also {scan['untagged']} meshes in collections without Male or Female "
                                   "in the name (not counted)"))
        if checking:
            facts.append(_fact("re-reading the .blend..."))
        elif not blender_ok and os.path.isfile(files["blend"]):
            facts.append(_fact("Blender not found, so the .blend cannot be read (set PD_BLENDER)", "warn"))
        steps["body"] = {"ready": count > 0, "fp": None, "facts": facts,
                         "hint": (f"Build the {sex} body in {base}.blend, in a collection whose name says "
                                  f"{'Female' if sex == 'female' else 'Male'} (like {name.replace(' ', '')}{sex.title()}).")
                         if os.path.isfile(files["blend"]) else f"Start {base}.blend in models/characters/{rid}/."}

        glb = files["export"][sex]
        found = glb_findings(glb)
        gfp = fingerprint(glb)
        efacts, ok = [], bool(found) and "error" not in found
        if found and "error" in found:
            efacts.append(_fact("could not read: " + found["error"], "warn"))
        elif found:
            good_h = lo * (1 - HEIGHT_TOLERANCE) <= found["height"] <= hi * (1 + HEIGHT_TOLERANCE)
            efacts.append(_fact(f"{found['height']:.2f} m tall (range {lo:.2f} to {hi:.2f})", "good" if good_h else "warn"))
            over = found["triangles"] > measure_glb.BODY_TRIANGLE_BUDGET
            efacts.append(_fact(f"{found['triangles']:,} triangles (budget {measure_glb.BODY_TRIANGLE_BUDGET:,})",
                                "warn" if over else "good"))
            if found["facing"] == "front":
                efacts.append(_fact("faces Blender's Front view", "good"))
            elif found["facing"] == "back":
                efacts.append(_fact("faces backwards: the game would show its back", "warn"))
        steps["export"] = {"ready": ok, "fp": gfp, "facts": efacts,
                           "hint": f"Export the {sex} body as GLB to models/characters/{rid}/{os.path.basename(glb)}, facing Blender's Front view."}

        uv = found.get("uv") if ok else None
        ufacts = []
        if ok and uv is None:
            ufacts.append(_fact("the export has no UV map", "warn"))
        elif uv:
            ufacts.append(_fact(f"{uv['pieces']} pieces, {uv['used']:.0%} of the square used", "good" if uv["unwrapped"] else ""))
            if uv["unwrapped"]:
                if uv["overlap"] > 0.02:
                    ufacts.append(_fact(f"{uv['overlap']:.0%} overlapping (fine if mirrored halves are stacked on purpose)"))
            else:
                why = (f"pieces piled {uv['depth']:.0f} deep on average" if uv["depth"] > glb_checks.MAX_STACK_DEPTH
                       else f"{uv['outside']} corners outside the square")
                ufacts.append(_fact(f"not a real unwrap yet: {why}", "warn"))
        steps["uv"] = {"ready": bool(uv and uv["unwrapped"]), "fp": gfp, "facts": ufacts,
                       "hint": "Unwrap it (one UV map, pieces laid out in the square without piling up) and export again."}

        tex = found.get("texture") if ok else None
        steps["texture"] = {"ready": bool(tex), "fp": gfp, "facts": [_fact(f"texture {tex}", "good")] if tex else [],
                            "hint": "Texture it and export again with the texture included."}

        rig = found.get("rig") if ok else None
        rfacts = []
        if rig:
            rfacts.append(_fact(f"{rig['bones']} bones" + (f", {rig['animations']} animations" if rig["animations"] else ""), "good"))
        steps["rig"] = {"ready": bool(rig), "fp": gfp, "facts": rfacts,
                        "hint": "Rig it and export again with the armature (and its animations)."}

        game = mounted.get(rid)
        gfacts, in_game = [], False
        if game and os.path.isfile(game):
            same = ok and file_hash(game) == file_hash(glb)
            if same:
                in_game = True
                gfacts.append(_fact("race_model.gd mounts this export", "good"))
            elif sex == "male":
                gfacts.append(_fact("race_model.gd mounts a different file: the game copy is not this export", "warn"))
        steps["ingame"] = {"ready": in_game, "fp": fingerprint(game) if game else None, "facts": gfacts,
                           "hint": ("Ask Claude to put it in the game (copy the export into assets/ and add it to race_model.gd)."
                                    if sex == "male" else
                                    "Needs race_model.gd to choose a model by sex (not built yet); ask Claude.")}

        render = render_for(rid, sex, glb) if ok else None
        out["sexes"][sex] = {"steps": steps, "render": render, "height": found["height"] if ok else None}
    return out


# ------------------------------------------------------------------ state

def step_state(det: dict, rec: dict | None) -> str:
    """missing / ready / approved / changed for one step."""
    if rec and rec.get("approved_at"):
        if det["fp"] is not None and rec.get("fp") not in (None, det["fp"]):
            return "changed"
        return "approved" if det["ready"] or det["fp"] is None else "changed"
    return "ready" if det["ready"] else "missing"


def race_states() -> list:
    packs, mounted, progress = find_packs(), mounted_models(), load_progress()
    cards = []
    for rid, name, lo, hi in read_races():
        det = detect(rid, name, lo, hi, packs, mounted)
        rec_race = progress.get(rid, {})
        sexes = []
        for sex in SEXES:
            d = det["sexes"][sex]
            rows, current = [], None
            for key in STEP_KEYS:
                rec = rec_race.get("pack") if key == "pack" else rec_race.get(sex, {}).get(key)
                state = step_state(d["steps"][key], rec)
                rows.append({"key": key, "label": LABELS[key], "state": state,
                             "facts": d["steps"][key]["facts"], "hint": d["steps"][key]["hint"],
                             "approved_at": (rec or {}).get("approved_at"), "note": (rec or {}).get("note", "")})
                if current is None and state != "approved":
                    current = key
            cur = next((r for r in rows if r["key"] == current), None)
            if cur is None:
                status, who = "Done and in the game.", ""
            elif cur["state"] in ("ready", "changed"):
                status = (f"{cur['label']}: changed since you approved it. Look again and approve."
                          if cur["state"] == "changed" else f"{cur['label']} is ready for your approval.")
                who = "you"
            else:
                status, who = cur["hint"], "todo"
            last = max((i for i, r in enumerate(rows) if r["state"] in ("approved", "changed")), default=-1)
            sexes.append({"sex": sex, "steps": rows, "current": current, "status": status, "who": who,
                          "undo": rows[last]["key"] if last >= 0 else None, "render": d["render"],
                          "height": d["height"], "done": current is None})
        cards.append({"id": rid, "name": name, "lo": lo, "hi": hi,
                      "pack": os.path.basename(det["pack"]) if det["pack"] else None,
                      "checking": det["checking"], "sexes": sexes,
                      "history": list(reversed(rec_race.get("history", [])))[:12]})
    return cards


def apply(rid: str, sex: str, step: str, action: str, note: str) -> str:
    """Approve or undo one step after checking it applies right now. Returns the event text."""
    if step not in STEP_KEYS or sex not in SEXES or action not in ("approve", "undo"):
        raise ValueError("unknown step")
    card = next((c for c in race_states() if c["id"] == rid), None)
    if card is None:
        raise ValueError("unknown race")
    line = next(s for s in card["sexes"] if s["sex"] == sex)
    row = next(r for r in line["steps"] if r["key"] == step)
    progress = load_progress()
    race = progress.setdefault(rid, {})
    label = f"{LABELS[step]}{'' if step == 'pack' else f' ({sex})'}"
    if action == "approve":
        if step != line["current"] or row["state"] not in ("ready", "changed"):
            raise ValueError("that step is not ready for approval; refresh the page")
        det = detect(rid, card["name"], card["lo"], card["hi"], find_packs(), mounted_models())
        rec = {"approved_at": time.time(), "fp": det["sexes"][sex]["steps"][step]["fp"], "note": note[:300]}
        if step == "pack":
            race["pack"] = rec
        else:
            race.setdefault(sex, {})[step] = rec
        event = f"{label} approved"
    else:
        if step != line["undo"]:
            raise ValueError("only the latest approval can be undone; refresh the page")
        if step == "pack":
            other = next(s for s in card["sexes"] if s["sex"] != sex)
            if other["undo"] not in (None, "pack"):
                raise ValueError("the other line has later steps approved; undo those first")
            race.pop("pack", None)
        else:
            race.get(sex, {}).pop(step, None)
        event = f"{label} approval undone"
    race.setdefault("history", []).append({"at": time.time(), "event": event, "note": note[:300]})
    save_progress(progress)
    return event
