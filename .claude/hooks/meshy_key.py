"""Where the Meshy API key lives, shared by the MCP launcher and the spend gate.

The key sits in a file in a private folder OUTSIDE both repos. That folder's
path is never committed: it is written only in secret_paths.local.json next to
this script, which git ignores. A MESHY_API_KEY environment variable, if set,
still wins, and MESHY_API_KEY_FILE can point somewhere else.
"""

import json
import os

LOCAL_PATHS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "secret_paths.local.json")


def local_paths() -> dict:
    """The git-ignored settings naming the private folder; empty if absent."""
    try:
        with open(LOCAL_PATHS_FILE, encoding="utf-8-sig") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def key_file_path() -> str:
    return os.environ.get("MESHY_API_KEY_FILE") or local_paths().get("meshy_key_file", "")


def read_key() -> str:
    """Return the key, or raise RuntimeError. Never puts the key in the message."""
    key = os.environ.get("MESHY_API_KEY", "").strip()
    if key:
        return key
    path = key_file_path()
    if not path:
        raise RuntimeError("no MESHY_API_KEY variable and no key file configured "
                           "(secret_paths.local.json is missing or has no meshy_key_file)")
    try:
        with open(path, encoding="utf-8-sig") as f:
            key = f.read().strip()
    except FileNotFoundError:
        raise RuntimeError("the configured key file does not exist")
    if not key:
        raise RuntimeError("the configured key file is empty")
    return key
