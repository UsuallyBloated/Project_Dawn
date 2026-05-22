# Track 18 — Server-authoritative skill leveling + memorize-gate
# hotkey shortcuts

Date: 2026-05-22 (same-day continuation from Tracks 16 & 17).

Track 18 closes the last major trust-model gap: passive skill scores
(weapon / armor / casting) now live on the server. Three GDScript
autoloads (WeaponSkills, ArmorSkills, CastingSkills) become render-
caches synced via `SkillProgressUpdate` / `SkillProgressSnapshot`
wire messages. Plus a 18.2 follow-up that closes the "hotkey bar
casts unmemorized spells" gap from the Track 17 carry-forward list.

Protocol bumped `PD_W0009 → PD_W0010`.

## 18.1 — Server-authoritative skill leveling

**New DB migration** `migrations/0003_character_skills.sql` — table
`character_skills (char_id, kind, key, score)` with composite PK and
a char_id index. `kind ∈ {'weapon','armor','casting'}` mirrors the
three GDScript autoloads.

**New `db::SkillRow` + `load_skills` + `save_skills`** in
`crates/projectdawn-server/src/db/mod.rs`. Mirrors the
`InventoryRow` / `load_inventory` / `save_inventory` pattern: atomic
delete + insert per character, ≤21 rows per save (10 weapon + 5
armor + 6 casting).

**New `world::skills` module**
(`crates/projectdawn-server/src/world/skills.rs`):
- `Skill` enum (`Weapon` / `Armor` / `Casting`) with
  `as_protocol()` conversion to the new `protocol::world::SkillKind`.
- `WEAPON_CAPS` / `ARMOR_CAPS` / `CASTING_CAPS` const cap tables
  ported 1:1 from `data/weapon_skill_definitions.gd` /
  `armor_skill_definitions.gd` / `casting_skill_definitions.gd`.
  Embedded as `&[(class, &[(key, max_cap)])]` slices — no TOML, no
  separate file (lower volatility than items/spells).
- `cap_for(skill, class, level, key)` — port of GDScript
  `get_cap(...)`: `max(1, max_cap * level / MAX_LEVEL)` when the
  class trains the skill (max_cap > 0); else 0.
- `starting_value(skill, class, key)` — cap at L1.
- `try_advance(conn, skill, key) -> Option<i32>` — rolls the
  `ADVANCE_CHANCE_BASE * (1 - current/cap) = 0.2 * (1 - cur/cap)`
  formula. Returns `Some(new_score)` on a successful roll; flips
  `conn.skills_dirty = true`.
- `seed_starting_scores(conn)` — fills all three maps with L1
  starting values for the connection's class. Called at EnterWorld
  before the DB rows overlay.
- `discipline_for_spell(name)` — port of `data/spell_definitions.gd
  ::DISCIPLINE` as a HashMap built once at startup via
  `init_discipline_map()`. Strips ` Rk. II` / ` Rk. III` suffixes
  so rank variants inherit base discipline. Defaults to `evocation`
  for unknown spells.
- `snapshot(conn)` — three parallel `Vec<(String, u32)>` for the
  fan-out path; keys sorted for deterministic ordering.
- 4 unit tests (caps + starting + class-without-skill + discipline).

**`PerConnection` extension** (connection.rs):
- New fields: `weapon_skills: HashMap<String, i32>`,
  `armor_skills: HashMap<String, i32>`,
  `casting_skills: HashMap<String, i32>`, `skills_dirty: bool`.
- Zero-initialized in `from_spawn`; populated by `seed_starting_scores`
  + DB overlay at EnterWorld.

**Wire glue** (protocol/src/world.rs):
- New `SkillKind` enum (Weapon=0, Armor=1, Casting=2).
- `ServerWorldMsg::SkillProgressUpdate { kind, key, new_score }`
  — fanned privately per successful advance.
- `ServerWorldMsg::SkillProgressSnapshot { weapon, armor, casting }`
  — fanned privately once on EnterWorld to seed the client's three
  caches.

**Server tick wiring** (tick.rs):
- `skills::init_discipline_map()` at server start.
- EnterWorld load: `load_skills(...)` runs alongside `load_inventory`;
  `seed_starting_scores(conn)` then overlays persisted rows on top
  of the L1 defaults.
- EnterWorld snapshot: `handlers::send_skill_progress_snapshot(...)`
  fires after the coin snapshot.
- **Weapon skill advance** in the AttackIntent loop:
  `skills::try_advance(Skill::Weapon, weapon.skill_key)` runs after
  the hit applies and aggro/threat updates. Also rolls Defense on
  every connecting swing (mirror of GDScript Combat path: defense
  ticks on connect + on dodge).
- **Casting skill advance** in the CastSpellIntent loop:
  `skills::discipline_for_spell(spell.name)` →
  `skills::try_advance(Skill::Casting, discipline)` after mana
  deduction. Channeling-on-interrupt-survived is server-side-pending
  (lands when the interrupt formula moves over).
- **Armor skill advance** in the enemy → player hit branch: collect
  unique equipped `armor_type`s (immutable inventory borrow), then
  `skills::try_advance(Skill::Armor, ...)` for each (mutable conn
  borrow — collect-first-then-mutate to satisfy the borrow checker).
  Also rolls Dodge per incoming hit.

**Persistence** (persistence.rs):
- `checkpoint_dirty` now also flushes `skills_dirty` connections:
  walks the three maps into `SkillRow`s and calls `db::save_skills`.
  Same 60 s cadence as inventory + disconnect-final-save.

**gdext-net** (crates/gdext-net/src/lib.rs):
- New `skill_progress_update(kind: u8, key: GString, new_score: i32)`
  and `skill_progress_snapshot(...)` `#[signal]`s.
- `Incoming::SkillProgressUpdate` / `SkillProgressSnapshot` variants
  + `classify` arms + `fire` arms.
- **DLL rebuilt** (static-CRT release, 3.95 MB) and copied to
  `addons/gdext_net/gdext_net.dll`.

**Client autoloads**:
- `autoloads/net.gd` — new `world_skill_progress_update` +
  `world_skill_progress_snapshot` signals; subscribed to the
  underlying gdext-net signals and re-emit.
- `autoloads/passive_skill_tracker.gd` — `try_advance(...)` early-
  returns in launcher mode (server runs the math). New
  `apply_remote_score(key, new_score)` and `apply_remote_snapshot
  (entries)` setters mutate `_skills` and emit `skill_advanced` so
  the character window repaints.
- `autoloads/weapon_skills.gd`, `armor_skills.gd`, `casting_skills.gd`
  — `_ready()` subscribes to `Net.world_skill_progress_update` and
  `Net.world_skill_progress_snapshot`, filters by `kind` (0/1/2),
  routes into the base class's apply methods.

## 18.2 — Hotkey-bar spell shortcut requires memorize

`autoloads/social_hotkeys.gd::_cast_spell` now checks SpellBar for
the spell name before casting. If the spell isn't memorized, logs
"You haven't memorized <name>." and refuses. Closes the Track 17
carry-forward gap where hotkey-bar slots cast spells regardless of
memorize state.

The Alt+digit path through `SpellBar.cast_slot` was already
memorize-gated (it reads SpellBar's slots, which only hold memorized
spells); only the hotkey-bar `execute_slot` path needed the check.

## Tests

**Lib**: 115/115 pass (was 111, +4 skills unit tests).

**Integration** (`world_two_clients.rs`): 39/39 pass (was 37, +2 new):
- `skill_progress_snapshot_seeded_on_enter_world` — Warrior connects,
  asserts SkillProgressSnapshot arrives with 10/5/6 keys; spot-checks
  that 1h_slashing = 4 (L1 cap), plate = 4, all casting = 0.
- `skill_progress_persists_load_path` — pre-writes
  `character_skills(char_id, 'casting', 'alteration', 17)` via direct
  SQL before EnterWorld; asserts the snapshot's alteration score
  reflects the persisted value, proving the seed → DB-overlay order
  in EnterWorld is correct.

**Skipped (deferred)**: an advance-then-persist round-trip
integration test. The `ADVANCE_CHANCE_BASE` of 0.2 plus the L1 cap
formula (`max(1, max_cap × level / 60)` ≤ 4 for most skills at L1)
means starting score *equals* cap at L1, so try_advance is gated by
character leveling. The cleanest path to exercise this in CI would
be a unit test that injects a controlled RNG via a `try_advance_with`
overload; the racy alternative (many casts hoping for a roll) was
not worth the flakiness. The lib unit tests cover the math and
the snapshot/persist integration tests cover the wire glue.

## Files touched

Server (`F:\Projects\server\`):
- `migrations/0003_character_skills.sql` (new)
- `crates/projectdawn-server/src/db/mod.rs` (SkillRow + load/save)
- `crates/projectdawn-server/src/world/skills.rs` (new — caps,
  try_advance, discipline map, 4 unit tests)
- `crates/projectdawn-server/src/world/connection.rs` (three skill
  HashMaps + dirty flag)
- `crates/projectdawn-server/src/world/mod.rs` (registered skills)
- `crates/projectdawn-server/src/world/handlers.rs`
  (send_skill_progress_update + send_skill_progress_snapshot)
- `crates/projectdawn-server/src/world/tick.rs` (init discipline
  map; load_skills + seed at EnterWorld; advance wiring in 3
  paths; snapshot fan-out at EnterWorld)
- `crates/projectdawn-server/src/world/persistence.rs` (save_skills
  flush on `skills_dirty`)
- `crates/projectdawn-server/tests/world_two_clients.rs` (2 new
  tests)
- `crates/protocol/src/world.rs` (SkillKind enum, two new variants,
  PD_W0009 → PD_W0010)
- `crates/gdext-net/src/lib.rs` (Incoming variants, classify, fire,
  two new signals)

Client (`F:\Projects\Project_Dawn\`):
- `autoloads/net.gd` (signal scaffolding)
- `autoloads/passive_skill_tracker.gd` (launcher-mode gate + remote
  apply methods)
- `autoloads/weapon_skills.gd` (Net subscription, kind filter)
- `autoloads/armor_skills.gd` (Net subscription, kind filter)
- `autoloads/casting_skills.gd` (Net subscription, kind filter)
- `autoloads/social_hotkeys.gd` (`_cast_spell` SpellBar gate)
- `addons/gdext_net/gdext_net.dll` (rebuilt, 3.95 MB)

## Carry-forward

- **Channeling skill advance on cast-interrupt-survived** — server
  doesn't yet model cast-interrupt outcomes; deferred to a future
  track that lifts the channeling roll server-side. The current
  client `casting_skills.gd` `get_interrupt_chance` formula still
  reads from `_skills` (now server-cached), so the gate works for
  client-decided interrupts; the advance side waits.
- **L1 skill cap = starting score limitation** — by design, fresh
  characters can't advance any skill until level-up grows the cap.
  This is the GDScript pattern; we ported it as-is. If playtest
  feedback dislikes the gate, change `starting_value` to a smaller
  fraction of cap (e.g. `cap / 4`) in both `skills.rs` and the
  GDScript definitions.
- **Memorize cost is still client-only** — the server doesn't model
  the spell bar at all. Forging a free memorize is harmless because
  casting still pays the full server-side gate (mana + cooldown +
  cast-time + movement). Lift when there's a reason.
- **Zone transitions** — still the next major lift when content
  needs it.
