#!/usr/bin/env python3
# Track 14.1 bootstrap — one-shot .tres → items.toml generator.
#
# Walks data/loot/items/*.tres, parses the [resource] block of each
# ItemData resource, and emits a single items.toml the server consumes
# via include_str!. The canonical regeneration tool is the GDScript
# editor script tools/export_items.gd; this Python one-shot exists
# only because the editor script can't be invoked headlessly and we
# need the full 157-entry registry seeded in one shot.
#
# Run from repo root: python tools/export_items_oneshot.py
# Output: F:/Projects/server/crates/projectdawn-server/data/items.toml

from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
ITEMS_DIR = REPO / "data" / "loot" / "items"
OUTPUT = Path("F:/Projects/server/crates/projectdawn-server/data/items.toml")

# Mirrors `ItemData.Type` order in scripts/item_data.gd. Index = numeric
# `type` field in the .tres file; value = the snake_case discriminant
# the Rust `ItemType` enum expects (matches #[serde(rename_all = "snake_case")]).
TYPE_NAMES = [
    "weapon", "offhand", "head", "chest", "legs", "feet", "hands",
    "ring", "neck", "consumable", "misc", "augment", "bag",
]

# Field rename map: client .tres field → server TOML field. Anything
# not in here is dropped (description, icon, socketed_augments, etc.).
RENAMES = {
    "item_name":           "name",
    "type":                "_type_idx",  # special: int → enum string
    "stack_size":          "stack_size",
    "rarity":              "rarity",
    # Stat affixes
    "bonus_strength":      "str_bonus",
    "bonus_dexterity":     "dex_bonus",
    "bonus_agility":       "agi_bonus",
    "bonus_intelligence":  "int_bonus",
    "bonus_wisdom":        "wis_bonus",
    "bonus_charisma":      "cha_bonus",
    "bonus_constitution":  "con_bonus",
    "bonus_max_hp":        "max_hp_bonus",
    "bonus_max_mp":        "max_mp_bonus",
    "bonus_max_stamina":   "max_stamina_bonus",
    # Weapon
    "weapon_damage_min":   "damage_min",
    "weapon_damage_max":   "damage_max",
    "weapon_delay":        "weapon_delay",
    "weapon_skill":        "skill",
    "is_two_handed":       "is_two_handed",
    "is_ranged":           "is_ranged",
    # Armor
    "bonus_armor":         "armor",
    "armor_type":          "armor_type",
    # Bag
    "bag_num_slots":       "bag_num_slots",
    # Consumable
    "heal_on_use":         "heal_on_use",
    "mp_on_use":           "mp_on_use",
    "is_food":             "is_food",
    "is_drink":            "is_drink",
    "food_hp_regen":       "food_hp_regen",
    "food_mp_regen":       "food_mp_regen",
    "food_duration":       "food_duration",
    # Proc
    "proc_chance":         "proc_chance",
    "proc_damage":         "proc_damage",
    "proc_damage_type":    "proc_damage_type",
    "proc_name":           "proc_name",
    # Augmentation
    "gem_slots":           "gem_slots",
    # Vendor
    "vendor_price":        "vendor_price",
}

# Field order in the emitted [[item]] block. path + name + item_type +
# stack_size always come first; the rest follow only if present.
EMIT_ORDER = [
    "path", "name", "item_type", "rarity", "stack_size",
    "damage_min", "damage_max", "weapon_delay", "skill",
    "is_two_handed", "is_ranged",
    "armor", "armor_type",
    "str_bonus", "dex_bonus", "agi_bonus", "int_bonus", "wis_bonus",
    "cha_bonus", "con_bonus",
    "max_hp_bonus", "max_mp_bonus", "max_stamina_bonus",
    "bag_num_slots",
    "heal_on_use", "mp_on_use",
    "is_food", "is_drink", "food_hp_regen", "food_mp_regen", "food_duration",
    "proc_chance", "proc_damage", "proc_damage_type", "proc_name",
    "gem_slots",
    "vendor_price",
]


RESOURCE_BLOCK = re.compile(r"\[resource\](.*)", re.DOTALL)
KV_LINE = re.compile(r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+?)\s*$")


def parse_value(raw: str):
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return ("str", raw[1:-1])
    if raw in ("true", "false"):
        return ("bool", raw == "true")
    # Integer
    try:
        return ("int", int(raw))
    except ValueError:
        pass
    # Float
    try:
        return ("float", float(raw))
    except ValueError:
        pass
    # ExtResource / Array / unsupported — drop.
    return ("skip", None)


def toml_emit(kind: str, val) -> str:
    if kind == "str":
        return '"' + val.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if kind == "bool":
        return "true" if val else "false"
    if kind == "int":
        return str(val)
    if kind == "float":
        s = str(val)
        if "." not in s and "e" not in s.lower():
            s += ".0"
        return s
    return ""


def parse_tres(path: Path) -> dict | None:
    text = path.read_text(encoding="utf-8")
    m = RESOURCE_BLOCK.search(text)
    if not m:
        return None
    body = m.group(1)
    fields: dict[str, tuple[str, object]] = {}
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("["):
            continue
        km = KV_LINE.match(line)
        if not km:
            continue
        key, raw = km.group(1), km.group(2)
        if key not in RENAMES:
            continue
        kind, val = parse_value(raw)
        if kind == "skip":
            continue
        fields[RENAMES[key]] = (kind, val)
    return fields


def emit_item(rel_name: str, fields: dict) -> list[str]:
    # Resolve item_type from numeric index.
    type_idx_entry = fields.pop("_type_idx", None)
    if type_idx_entry is None:
        print(f"  ! {rel_name}: no `type` field, skipping")
        return []
    type_idx = type_idx_entry[1]
    if not isinstance(type_idx, int) or type_idx < 0 or type_idx >= len(TYPE_NAMES):
        print(f"  ! {rel_name}: invalid type {type_idx}, skipping")
        return []
    item_type = TYPE_NAMES[type_idx]
    fields["item_type"] = ("str", item_type)
    fields["path"] = ("str", f"res://data/loot/items/{rel_name}")

    lines = ["[[item]]"]
    for key in EMIT_ORDER:
        entry = fields.get(key)
        if entry is None:
            continue
        kind, val = entry
        # Suppress noise zeros / empties for optional fields. Always
        # emit path / name / item_type / stack_size.
        if key not in ("path", "name", "item_type", "stack_size"):
            if kind == "int" and val == 0:
                continue
            if kind == "float" and val == 0.0:
                continue
            if kind == "bool" and val is False:
                continue
            if kind == "str" and val == "":
                continue
        lines.append(f"{key} = {toml_emit(kind, val)}")
    lines.append("")
    return lines


def main():
    if not ITEMS_DIR.is_dir():
        raise SystemExit(f"items dir missing: {ITEMS_DIR}")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    tres_files = sorted(ITEMS_DIR.glob("*.tres"))
    print(f"Parsing {len(tres_files)} .tres files from {ITEMS_DIR}")

    out: list[str] = [
        "# AUTO-GENERATED — do not edit by hand.",
        "# Bootstrap source: Project_Dawn/tools/export_items_oneshot.py",
        "# Canonical regen tool: Project_Dawn/tools/export_items.gd",
        "# (open in Godot editor, File → Run; matches this output).",
        "",
    ]
    written = 0
    for path in tres_files:
        fields = parse_tres(path)
        if fields is None:
            print(f"  ! {path.name}: no [resource] block")
            continue
        lines = emit_item(path.name, fields)
        if lines:
            out.extend(lines)
            written += 1

    OUTPUT.write_text("\n".join(out), encoding="utf-8")
    print(f"Wrote {written} items to {OUTPUT}")


if __name__ == "__main__":
    main()
