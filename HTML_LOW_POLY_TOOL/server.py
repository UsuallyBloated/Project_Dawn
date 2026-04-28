"""
Low-Poly Model Generator — local server (Ollama backend)
No API key required. Runs the model entirely on your machine.

Setup (one-time):
  1. Install Ollama from https://ollama.com
  2. Run:  ollama pull llama3.2
  3. Start this server:  python server.py
  4. Open:  http://localhost:3000

To use a different model, set OLLAMA_MODEL in .env:
  OLLAMA_MODEL=mistral
  OLLAMA_MODEL=llama3.1:8b
"""

import json
import os
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory

BASE_DIR = Path(__file__).parent
load_dotenv(BASE_DIR / ".env")

OLLAMA_URL   = os.environ.get("OLLAMA_URL",   "http://127.0.0.1:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3.2")

app = Flask(__name__, static_folder=str(BASE_DIR))

SYSTEM_PROMPT = """You are a 3D low-poly model generator. When given a description, output ONLY a valid JSON object — no explanation, no markdown, no code fences.

JSON format:
{
  "name": "short descriptive name",
  "vertices": [[x, y, z], ...],
  "faces": [
    {"indices": [a, b, c], "color": "#RRGGBB"},
    ...
  ]
}

Rules:
- 150-350 vertices; all faces are triangles (3 zero-based indices)
- Vertices fit within [-1.5, 1.5] on all axes, centered near origin
- 300-700 faces; use enough geometry that the object is clearly recognizable
- Break up large flat areas with extra edge loops so the silhouette reads well
- Adjacent faces should use slightly different shades for depth and visual interest
- Colors must be harmonious hex strings like "#a34f2b"
- Output ONLY the JSON object, nothing else"""


def ollama_available():
    """Return list of pulled model names, or None if Ollama isn't running."""
    try:
        with urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=3) as r:
            data = json.loads(r.read())
            return [m["name"] for m in data.get("models", [])]
    except Exception:
        return None


def call_ollama(description: str, style: str) -> dict:
    user_msg = f"Generate a low-poly 3D model of: {description}"
    if style:
        user_msg += f"\nStyle: {style}"

    payload = json.dumps({
        "model": OLLAMA_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": user_msg},
        ],
        "stream": False,
        "format": "json",          # Ollama constrains output to valid JSON
        "options": {"temperature": 0.7},
    }).encode()

    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            result = json.loads(r.read())
    except urllib.error.URLError as e:
        raise RuntimeError(
            "Cannot reach Ollama. Is it running? Start it with:  ollama serve"
        ) from e

    raw = result.get("message", {}).get("content", "").strip()

    # Extract JSON even if the model wrapped it in fences
    match = re.search(r"\{[\s\S]*\}", raw)
    if not match:
        raise ValueError("Model returned no JSON object — try regenerating.")

    model_data = json.loads(match.group())

    if not isinstance(model_data.get("vertices"), list) or \
       not isinstance(model_data.get("faces"), list):
        raise ValueError("Model data is missing vertices or faces.")

    return model_data


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
            "error": f'Model "{OLLAMA_MODEL}" not pulled yet. Run: ollama pull {OLLAMA_MODEL}',
        }), 503
    return jsonify({"ok": True, "model": OLLAMA_MODEL, "models": models})


@app.route("/api/generate", methods=["POST"])
def generate():
    body = request.get_json(force=True, silent=True) or {}
    description = (body.get("description") or "").strip()
    style       = (body.get("style")       or "").strip()

    if not description:
        return jsonify({"error": "Description is required"}), 400

    try:
        model_data = call_ollama(description, style)
        print(f'  Generated: "{model_data.get("name")}" — '
              f'{len(model_data["vertices"])}v {len(model_data["faces"])}f')
        return jsonify(model_data)

    except json.JSONDecodeError:
        return jsonify({"error": "Model returned invalid JSON — try regenerating."}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    print(f"\n  Checking Ollama…")
    models = ollama_available()
    if models is None:
        print("  WARNING: Ollama doesn't appear to be running.")
        print("           Start it with:  ollama serve\n")
    else:
        has_model = any(OLLAMA_MODEL in m for m in models)
        if not has_model:
            print(f"  WARNING: Model '{OLLAMA_MODEL}' not found.")
            print(f"           Pull it with:  ollama pull {OLLAMA_MODEL}\n")
        else:
            print(f"  Ollama ready — model: {OLLAMA_MODEL}")

    port = int(os.environ.get("PORT", 3000))
    print(f"\n  Low-Poly Model Generator → http://localhost:{port}\n")
    app.run(host="127.0.0.1", port=port, debug=False)
