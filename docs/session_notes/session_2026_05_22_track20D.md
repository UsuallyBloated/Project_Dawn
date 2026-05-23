# Track 20D — Cross-cutting cleanups (server spells + named-mob loot)

Date: 2026-05-22 (continuation from Track 19A).

Closes two long-standing playtest gaps from the Track 16 → 19 carry-
forward list. No new player-facing features; just plugs visible
bugs that surfaced as silent rejects in the server log + phantom
client-side animations.

## 20D.1 — Missing spells in `spells.toml`

The server's `spells::lookup` rejects casts of any spell name not in
`crates/projectdawn-server/data/spells.toml` with
`"unknown spell name — server-side cast dropped"`. The client's
optimistic-render pipeline still fires the animation locally, so the
player sees a fake damage number but nothing actually applies. Three
casts were caught by this gap:

- **Lifetap** (Shadow Knight, min_level 4). The Track 9 fill-in
  pass added Lifetap Rk. II but missed the base.
- **Soul Drain** (Necromancer, min_level 4). Same gap.
- **Bind Affinity** (every caster, min_level 1, target_type `"BIND"`).
  Server falls through to the "target_type not yet processed" default
  arm — that's fine here because the bind point itself is still
  client-side state on `PlayerStats`; the mana deduction is the only
  server-side effect needed.

All three added with fields mirroring the GDScript definitions in
`data/spell_definitions.gd`. Lib test `embedded_toml_parses` confirms
the new entries deserialise cleanly.

## 20D.2 / 20D.3 / 20D.5 — Named-mob loot moves to `.tres`

`data/named_mob_definitions.gd` previously held all named-boss loot
as inline dicts. `NamedMobDefinitions.make_item(d)` built a runtime
ItemData from each dict at apply-named time. These items had no
`resource_path`, which meant:

- Server registry (`items.toml`) didn't know about them.
- Equip / sell / destroy attempts against these items got
  `"unknown item path"` server-side and silently failed.

10 new `.tres` files in `data/loot/items/`:

| Boss | Guaranteed | Rare |
|---|---|---|
| Rotfang | `rotfangs_fang.tres` | `predators_collar.tres` |
| Greth Bonecrusher | `gnoll_chiefs_seal.tres` | `bonecrushers_war_axe.tres` |
| Ancient Crawler | `pristine_venom_sac.tres` | `chitinous_ring.tres` |
| Sable | `sable_wing_membrane.tres` | `shadow_signet.tres` |
| The Undying | `undying_marrow.tres` | `cursed_femur.tres` |

`named_mob_definitions.gd` rewritten:
- `guaranteed_loot: Array[String]` of resource paths.
- `rare_loot: Array[{path, drop_chance}]`.
- New `load_item(path) -> ItemData` helper with a missing-file
  warning so an authoring typo can't silently drop nothing.
- Old `make_item` / `_parse_type` / `_parse_rarity` helpers removed
  (no longer reachable).

`enemy.gd::apply_named` updated:
- `for path: String in data.get("guaranteed_loot", [])` →
  `NamedMobDefinitions.load_item(path)`.
- `for d: Dictionary in data.get("rare_loot", [])` reads
  `d["path"]` and rolls `d.get("drop_chance", 0.2)`.

## 20D.4 — `items.toml` regenerated

`python tools/export_items_oneshot.py` walks `data/loot/items/*.tres`
and emits the canonical `items.toml`. 158 → 168 entries (the 10 new
named drops). Server lib tests still pass — `items::lookup` finds
the new entries by path; the embedded TOML parses cleanly.

## Tests

- **Lib**: 116/116 pass.
- **Integration**: 39/40 in one full-suite run, 40/40 in isolation.
  The full-suite failure was `pet_pulls_aggro_via_threat_reaggro` —
  documented pre-existing AI-walks-into-melee flake under parallel-
  test scheduling pressure. Not a Track 20D regression.

## Files touched

Server (`F:\Projects\server\`):
- `crates/projectdawn-server/data/spells.toml` (+3 entries: Lifetap,
  Soul Drain, Bind Affinity)
- `crates/projectdawn-server/data/items.toml` (regenerated from
  `.tres`; 158 → 168 entries)

Client (`F:\Projects\Project_Dawn\`):
- `data/loot/items/{rotfangs_fang, predators_collar, gnoll_chiefs_seal,
  bonecrushers_war_axe, pristine_venom_sac, chitinous_ring,
  sable_wing_membrane, shadow_signet, undying_marrow,
  cursed_femur}.tres` (new — 10 files)
- `data/named_mob_definitions.gd` (rewritten — paths instead of dicts)
- `scripts/enemy.gd` (`apply_named` consumes the new shape)

## Carry-forward

- **`make_item` / `_parse_type` / `_parse_rarity` removal** — these
  static helpers are no longer called. The current edit deletes
  them; if any future test code or doc references them they'll
  fail to compile, which is the desired signal.
- **Destroy button "some items not others"** — still no repro from
  the playtest log. With named-mob items now in the registry, one
  category of "destroy fails silently" is closed. If a repro still
  surfaces, look at `bag_window._confirm_destroy` + the drag-source
  state.
- **target_type `"BIND"` server arm** — Bind Affinity currently
  falls through to the "not yet processed" default after mana
  deduction. The bind point itself is still client-side on
  `PlayerStats`. If bind needs to be server-authoritative (e.g.
  for instanced dungeons that cancel binds), add a `"BIND"` arm to
  the target_type match in `tick.rs`.
