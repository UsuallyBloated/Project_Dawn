# Track 18 Handoff — Skill leveling server-auth + memorize/cast polish

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Track 17 (2026-05-22) finished the memorize-cost / cap workflow on
the client and the cooldown / movement-during-cast server-auth lift.
See `session_2026_05_22_track17.md`. After Track 17 the only major
trust-model carry-forward is **skill leveling** — Weapon / Armor /
Casting skill autoloads still mutate client-side only.

Track 18 has one big lift (18.1) and a UX polish pass (18.2). The
remaining items in the Track 17 carry-forward list are smaller and
roll into 18.2 as optional follow-ups.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_22_track17.md` — Track 17
   closeout. The cooldown HashMap pattern on PerConnection is the
   template for the skill-progress map in 18.1.
3. `docs/playtest_notes/` — any new notes the user adds before
   Track 18 starts.
4. `autoloads/weapon_skills.gd`, `autoloads/armor_skills.gd`,
   `autoloads/casting_skills.gd` — all extend
   `autoloads/passive_skill_tracker.gd`. The `try_advance` path
   is the entry point that needs to move server-side.
5. `crates/projectdawn-server/src/world/handlers.rs` — the
   `Attack` arm (~line 250) and `CastSpellIntent` resolver fire at
   the moments where skills should advance.

## Four repos at handoff

| Repo | Path | Branch |
|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` |
| Server | `F:\Projects\server\` | `main` |
| Launcher | `F:\Projects\launcher\` | `main` |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` |

Track 16 + 17 changes still uncommitted (Memorize / SpellBar
autoloads + hotbar + spell_book + social_hotkeys + server tick &
handlers & connection edits). Read the working-tree diff before
starting — Track 18.1's server lift will share the connection-state
expansion pattern.

## Sub-task 18.1 — Server-authoritative passive skill leveling (~1.5 sessions)

`PassiveSkillTracker` (the base of WeaponSkills, ArmorSkills,
CastingSkills) tracks per-skill scores 0-300 client-side and
advances them on use (`try_advance(key)`). A forged client can
straight-line a maxed score with no actual play. Lift to server
following the Track 14.2 pattern (per-conn map + signed deltas).

**Server-side touchpoints:**

- `crates/projectdawn-server/src/world/connection.rs` — three new
  `HashMap<String, i32>` fields:
  `weapon_skills: HashMap<String, i32>`,
  `armor_skills: HashMap<String, i32>`,
  `casting_skills: HashMap<String, i32>`. Keys mirror the GDScript
  `WeaponSkillDefinitions.CLASS_CAPS` / equivalents. Loaded from a
  new `character_skills` SQLite table (schema migration needed).
- `crates/projectdawn-server/src/world/skills.rs` (new module) —
  port `try_advance` math: cap from class table, advance chance
  formula, etc. Helpers `weapon_try_advance(conn, key)` /
  `casting_try_advance(conn, key)` / `armor_try_advance(conn, key)`
  return the new score so the dispatcher can fan a delta.
- Wire points:
  - Server's `Attack` resolver (`handlers.rs` ~the `Outcome::AttackIntent`
    arm) fires after a hit lands. Look up the weapon's skill key
    from `items.toml` (already loaded; new field?) and call
    `weapon_try_advance`.
  - `tick.rs::cast_spell_intents` loop, on a successful cast
    landing, look up the spell's discipline (`Healing` /
    `Evocation` / etc. — port from
    `data/spell_definitions.gd::DISCIPLINE`) and call
    `casting_try_advance`.
  - Armor advances are trickier — they fire when a hit lands on
    the player, scaled by armor type. The existing client path is
    in `armor_skills.gd::try_advance`. Port the trigger to the
    server's enemy → player attack arm in `tick.rs`.
- New `ServerWorldMsg::SkillProgressUpdate { kind, key, new_score
  }` for fan-out. Kind = `0` weapon / `1` armor / `2` casting (or
  a string `"weapon" / "armor" / "casting"` — pick the shape
  matching the existing enum style).
- Persistence: new migration `0007_character_skills.sql` with
  `(char_id, kind, key, score)` PK + index on char_id. Save on
  disconnect + checkpoint cadence.

**Client-side touchpoints:**

- `autoloads/passive_skill_tracker.gd` — `try_advance(key)`
  becomes a no-op in launcher mode (the server runs the math).
  The autoload keeps the `current_score(key)` and `cap_for(key)`
  read paths so the character window still renders.
- `autoloads/net.gd` — new `world_skill_progress` signal fanning
  out from a new `NetClient` signal in `crates/gdext-net/src/lib.rs`
  (mirror the `world_xp_gained` pattern). `weapon_skills.gd` /
  `armor_skills.gd` / `casting_skills.gd` subscribe and update
  their local cache + emit `skill_changed` for the character
  window.
- `crates/gdext-net/src/lib.rs` — new `Incoming::SkillProgress`
  variant, decode arm, signal emit. DLL rebuild + copy to
  `addons/gdext_net/gdext_net.dll`.

**Edge cases:**

- **Solo / Test Room** keeps the legacy client-side try_advance
  path (gated on `Net.is_launcher_mode()` returning false in
  `passive_skill_tracker.gd`). Don't drop the local math; it's
  still load-bearing for offline play.
- **First-connect seed**: server reads `character_skills` rows on
  `load_character`, populates the per-conn maps; sends an initial
  `SkillProgressSnapshot { weapon: [...], armor: [...], casting:
  [...] }` (one message, not per-skill) right after `ConnectOk` to
  populate the client cache. Keeps the wire chatter sane.
- **Migration on first connect with no skill rows**: empty maps.
  Skill advances populate them on demand. No special-case needed.

**Tests:**

- `crates/projectdawn-server/tests/world_two_clients.rs`:
  - `weapon_skill_advances_on_hit` — Warrior swings a sword at an
    enemy; assert SkillProgress fans with the right key + new
    score > 0.
  - `casting_skill_advances_on_successful_cast` — Cleric casts
    Healing Wave; assert casting SkillProgress fans for the
    Healing discipline.
  - `skill_progress_persists_across_reconnect` — advance a few
    points, disconnect, reconnect, assert the seed snapshot
    carries the advanced score (mirror the existing
    `bag_contents_persist_across_reconnect` pattern).

This is the cleanest place to use the Track 14.2-style cache to
avoid recomputing chance formulas on every hit (the chance
calculation is cheap but reading the cap table per swing isn't
free).

---

## Sub-task 18.2 — Track 17 carry-forwards (~0.5 session)

Three smaller items from the Track 17 carry-forward list, none of
which need their own track:

**A. Hotkey-bar spell shortcut requires memorize.** Today the
context menu's `Assign Spell...` writes a spell to a hotkey-bar
slot, and that slot casts via `Spells.cast_spell` with no check
that the spell is also in `SpellBar`. Two options to close the
gap:
- **(a)** When a hotkey-bar slot of type SPELL is executed, check
  whether `SpellBar` contains the same spell. If not, fail with
  `"You haven't memorized that spell."` Easy, ~5 lines in
  `social_hotkeys.gd::_cast_spell`.
- **(b)** Drop spell assignment from the hotkey bar entirely. The
  spell bar is the only place spells live. Cleaner classic feel
  but removes a working feature.

Pick (a). User can revisit (b) later if it's still bothersome.

**B. Tighten memorize cancellation messages.** The current text
reads "Memorize interrupted (moved)." in CombatLog. After a few
real playtests, decide whether to:
- Drop the parenthetical reasons.
- Move to a transient on-screen toast instead of CombatLog.
- Keep as-is if the reasons turn out to be useful diagnostic.

Wait for playtest feedback before changing — don't pre-optimise.

**C. Server-side memorize cost (optional, defer if 18.1 is tight).**
Today the client enforces the memorize MP cost; a forged client
could lie. The server doesn't model the memorize bar at all, so
the integrity bar is: forged memorize → faster spell access, but
the cast still pays full MP + cooldown + cast-time + movement
gates. Low risk; defer unless 18.1 finishes early.

---

## Cross-cutting cleanups (still open from Track 16's handoff)

- **Soul Drain + Bind Affinity** not in server `spells.toml` —
  add ~10 lines of TOML, mirror the GDScript definitions.
- **Named-mob runtime loot has no .tres** — author ~15 .tres
  files from `data/named_mob_definitions.gd` inline dicts; regen
  `items.toml`.
- **Destroy button "some items not others"** — still no repro
  from playtest.

---

## Carry-forward beyond Track 18

- **Zone transitions** — server-side zone routing, world-token
  re-issue or re-handshake, position handoff, AOI grid per zone.
  Big track. Gated by content (currently one zone). When the
  second zone lands, this is the next major server lift.
- **PvP flagging** — design decision still pending (see the to-do
  list in `CLAUDE.md`). Alignment kill deltas exist; flagging
  trigger + consequences need a design call.
- **Mount system + corpse run** — content / mechanics rather than
  netcode. Hold until the content tracks pick them up.

---

## Known flaky tests

Same as Track 16 / 17 handoffs: `world_two_clients.rs` has 1-3
intermittent failures per full-suite run in the AI-walks-into-melee
timing tests:
- `lifesteal_spell_heals_caster`
- `player_attack_kills_enemy_and_corpse_despawns`
- `enemy_aggros_chases_and_attacks_player`
- `pet_pulls_aggro_via_threat_reaggro`
- `aoe_spell_damages_nearby_enemies`

All pass in isolation. Track 17's new cast-gate tests (cooldown +
move) are stable. If Track 18.1 adds AI-timing-dependent tests
(e.g. weapon-skill-advances-on-hit relies on the enemy being in
melee range), expect the same flaky-pattern under load.

A real fix: `--test-threads=1` on the CI profile, or replace
real-time waits with manual tick advancement. Still out of scope.

---

## Pick one and write the next handoff

Recommended start: **18.1 skill leveling server-auth.** Closes the
last major trust-model gap. The cooldown HashMap pattern from
Track 17 is the cleanest template — three parallel maps, three
mutation sites, one fan-out snapshot type. 18.2 fits afterwards if
there's time.
