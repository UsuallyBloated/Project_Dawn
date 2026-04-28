"""
Low-Poly Model Generator — local server (Ollama + vision backend)
No API key required. Runs entirely on your machine.

Setup:
  1. ollama pull llama3.2-vision
  2. ollama serve            (keep running in a separate terminal)
  3. python server.py
  4. Open http://localhost:3000

Optional .env settings:
  OLLAMA_MODEL=llama3.2-vision
  OLLAMA_URL=http://127.0.0.1:11434
"""

import base64
import json
import os
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory

BASE_DIR      = Path(__file__).parent
REFERENCE_DIR = BASE_DIR / "reference_images"
REFERENCE_DIR.mkdir(exist_ok=True)

load_dotenv(BASE_DIR / ".env")

OLLAMA_URL   = os.environ.get("OLLAMA_URL",   "http://127.0.0.1:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3.2-vision")

ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".webp"}

app = Flask(__name__, static_folder=str(BASE_DIR))

# ── System prompts ────────────────────────────────────────────────────────────

SYSTEM_TEXT = """You are a 3D low-poly model generator. Output ONLY a valid JSON object — no markdown, no explanation, no code fences.

JSON format:
{
  "name": "short descriptive name",
  "vertices": [[x, y, z], ...],
  "faces": [{"indices": [a, b, c], "color": "#RRGGBB"}, ...]
}

Rules:
- 60-120 vertices; triangles only (3 zero-based indices per face)
- Vertices within [-1.5, 1.5] on all axes, centered at origin
- 80-200 faces; capture the main silhouette and key features clearly
- Adjacent faces use slightly different shades for visual depth
- Colors are harmonious hex strings appropriate to the object
- Output ONLY the JSON object"""

SYSTEM_VISION = """You are a 3D low-poly model generator. Reference images are attached — look at them to understand the object's silhouette, proportions, and key features.

Output ONLY a valid JSON object — no markdown, no explanation, no code fences.

JSON format:
{
  "name": "short descriptive name",
  "vertices": [[x, y, z], ...],
  "faces": [{"indices": [a, b, c], "color": "#RRGGBB"}, ...]
}

Rules:
- Use the reference images to get proportions and silhouette right
- 60-120 vertices; triangles only (3 zero-based indices per face)
- Vertices within [-1.5, 1.5] on all axes, centered at origin
- 80-200 faces; make the shape recognizable from the reference
- Adjacent faces use slightly different shades for visual depth
- Sample colors from the reference images where possible
- Output ONLY the JSON object"""


# ── Helpers ───────────────────────────────────────────────────────────────────

def ollama_available():
    try:
        with urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=3) as r:
            data = json.loads(r.read())
            return [m["name"] for m in data.get("models", [])]
    except Exception:
        return None


def load_reference_images():
    """Return list of (filename, base64_string) for all images in REFERENCE_DIR."""
    images = []
    for p in sorted(REFERENCE_DIR.iterdir()):
        if p.suffix.lower() in ALLOWED_EXTS:
            images.append((p.name, base64.b64encode(p.read_bytes()).decode()))
    return images


def call_ollama(description: str, style: str) -> dict:
    refs = load_reference_images()
    has_refs = len(refs) > 0
    system = SYSTEM_VISION if has_refs else SYSTEM_TEXT

    user_msg = f"Generate a low-poly 3D model of: {description}"
    if style:
        user_msg += f"\nStyle: {style}"
    if has_refs:
        user_msg += f"\n\n{len(refs)} reference image(s) attached. Use them to guide the geometry and proportions."

    user_message = {"role": "user", "content": user_msg}
    if has_refs:
        # llama3.2-vision only supports one image — use the first reference
        user_message["images"] = [refs[0][1]]

    payload = json.dumps({
        "model":   OLLAMA_MODEL,
        "messages": [
            {"role": "system", "content": system},
            user_message,
        ],
        "stream":  False,
        "options": {"temperature": 0.6, "num_predict": 8192},
    }).encode()

    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            result = json.loads(r.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        print(f"  Ollama HTTP {e.code}: {body}")
        raise RuntimeError(f"Ollama rejected the request (HTTP {e.code}): {body}") from e
    except TimeoutError as e:
        raise RuntimeError("Generation timed out (10 min limit). Try a simpler description.") from e
    except urllib.error.URLError as e:
        if "timed out" in str(e).lower():
            raise RuntimeError("Generation timed out. Try a simpler description.") from e
        raise RuntimeError(f"Cannot reach Ollama: {e.reason}") from e

    raw = result.get("message", {}).get("content", "").strip()

    match = re.search(r"\{[\s\S]*\}", raw)
    if not match:
        raise ValueError("Model returned no JSON object — try regenerating.")

    model_data = json.loads(match.group())

    if not isinstance(model_data.get("vertices"), list) or \
       not isinstance(model_data.get("faces"), list):
        raise ValueError("Model data is missing vertices or faces.")

    model_data["_vision"] = has_refs
    model_data["_refs"]   = len(refs)
    return model_data


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return send_from_directory(BASE_DIR, "index.html")


@app.route("/api/status")
def status():
    models = ollama_available()
    if models is None:
        return jsonify({"ok": False, "error": "Ollama is not running. Start it with: ollama serve"}), 503
    has_model = any(OLLAMA_MODEL in m for m in models)
    if not has_model:
        return jsonify({
            "ok": False,
            "error": f'Model "{OLLAMA_MODEL}" not pulled. Run: ollama pull {OLLAMA_MODEL}',
        }), 503
    refs = load_reference_images()
    return jsonify({"ok": True, "model": OLLAMA_MODEL, "refs": len(refs)})


@app.route("/api/references", methods=["GET"])
def list_references():
    refs = []
    for p in sorted(REFERENCE_DIR.iterdir()):
        if p.suffix.lower() in ALLOWED_EXTS:
            b64 = base64.b64encode(p.read_bytes()).decode()
            mime = "image/jpeg" if p.suffix.lower() in {".jpg", ".jpeg"} else "image/png"
            refs.append({"name": p.name, "src": f"data:{mime};base64,{b64}"})
    return jsonify(refs)


@app.route("/api/references", methods=["POST"])
def upload_reference():
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400
    f = request.files["file"]
    ext = Path(f.filename).suffix.lower()
    if ext not in ALLOWED_EXTS:
        return jsonify({"error": f"Unsupported format. Use: {', '.join(ALLOWED_EXTS)}"}), 400
    # Sanitise filename
    safe = re.sub(r"[^\w.\-]", "_", f.filename)
    dest = REFERENCE_DIR / safe
    f.save(dest)
    print(f"  Reference saved: {safe}")
    return jsonify({"ok": True, "name": safe})


@app.route("/api/references/<filename>", methods=["DELETE"])
def delete_reference(filename):
    safe = re.sub(r"[^\w.\-]", "_", filename)
    target = REFERENCE_DIR / safe
    if target.exists() and target.parent == REFERENCE_DIR:
        target.unlink()
        return jsonify({"ok": True})
    return jsonify({"error": "File not found"}), 404


@app.route("/api/generate", methods=["POST"])
def generate():
    body        = request.get_json(force=True, silent=True) or {}
    description = (body.get("description") or "").strip()
    style       = (body.get("style")       or "").strip()

    if not description:
        return jsonify({"error": "Description is required"}), 400

    try:
        model_data = call_ollama(description, style)
        vision_tag = " [vision]" if model_data.get("_vision") else ""
        print(f'  Generated{vision_tag}: "{model_data.get("name")}" — '
              f'{len(model_data["vertices"])}v {len(model_data["faces"])}f')
        return jsonify(model_data)

    except json.JSONDecodeError:
        return jsonify({"error": "Model returned invalid JSON — try regenerating."}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── Startup ───────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print(f"\n  Checking Ollama…")
    models = ollama_available()
    if models is None:
        print("  WARNING: Ollama not running — start it with: ollama serve\n")
    else:
        has_model = any(OLLAMA_MODEL in m for m in models)
        if not has_model:
            print(f"  WARNING: '{OLLAMA_MODEL}' not found — run: ollama pull {OLLAMA_MODEL}\n")
        else:
            refs = load_reference_images()
            ref_note = f" · {len(refs)} reference image(s) loaded" if refs else " · no reference images"
            print(f"  Ollama ready — model: {OLLAMA_MODEL}{ref_note}")

    port = int(os.environ.get("PORT", 3000))
    print(f"\n  Low-Poly Model Generator → http://localhost:{port}\n")
    app.run(host="127.0.0.1", port=port, debug=False)
