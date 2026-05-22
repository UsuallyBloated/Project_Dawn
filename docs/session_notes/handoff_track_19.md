# Track 19 Handoff — Open scope (next playtest signal)

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Track 18 (2026-05-22) closed the last major server-authority gap:
passive skill leveling. After Track 18 the netcode trust model
covers movement (Track 2), enemies (Track 5), stats/PvP/buffs/groups
(Track 6), AOI (Track 7), AOE (Track 9), cast-time/cooldown/movement
(Tracks 10/17), pets (Tracks 11/12/15.3), inventory + equipment +
vendors (Tracks 13/14/15), and now skill leveling (18). The next
big track (zone transitions) is content-gated; until then Track 19
is **open scope — pick the strongest signal from the next playtest
or content backlog**.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_22_track18.md` — Track 18
   closeout. The skills HashMap + EnterWorld snapshot pattern is the
   template if a new system needs server-auth state.
3. `docs/playtest_notes/` — **check for new files dated after 2026-05-22.**
   That's the strongest signal for what to pick.
4. The To-Do list in `CLAUDE.md` — three large open items (Corpse
   run, Incoming /tell RPC, Mount system, PvP flagging) and a long
   tail of UI/content polish.

## Four repos at handoff

| Repo | Path | Branch |
|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` |
| Server | `F:\Projects\server\` | `main` |
| Launcher | `F:\Projects\launcher\` | `main` |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` |

**Working tree is heavy.** Tracks 16, 17, 18 are all uncommitted on
both client and server. Roll a commit early in Track 19 so the
boundaries stay visible.

```
git -C F:\Projects\Project_Dawn diff --stat
git -C F:\Projects\server diff --stat
```

Read the diff before starting Track 19 — there's a lot of context
in the in-flight changes.

## Recommended starting menu

In rough priority order. The user's playtest notes after Track 18
will likely override; treat this as a fallback when nothing's
urgent.

### Option A — Channeling skill on cast-interrupt-survived (~0.5 session)

Track 18 left the Channeling advance hook server-side-pending.
Today the GDScript `casting_skills.gd::get_interrupt_chance()` reads
the server-synced channeling score and decides whether an incoming
hit during a cast cancels it. But the advance side (channeling
ticks up when a hit survives) was client-only and is now neutered
by the launcher-mode gate in `passive_skill_tracker.gd`.

Lift: when the server's cast-interrupt formula runs (port from
GDScript `Spells.try_interrupt_cast`), call
`skills::try_advance(Skill::Casting, "channeling")` on the survive
branch. Fan SkillProgressUpdate.

Today the interrupt math lives client-only on `Spells.try_interrupt_cast`
— the server doesn't model the interrupt at all. So this is two
pieces: (a) port the interrupt formula to the server's incoming-
damage path for casting players, (b) wire the advance on survive.
Maybe a full session if (a) gets thorny.

### Option B — Channeling-on-interrupt deferred; pick a UI polish item (~1 session)

The to-do list in `CLAUDE.md` has several:
- **Target-of-target frame** — show what your target is targeting.
  Essential for group play. Reads `Combat.current_target.target`
  (already tracked on enemies) into a small frame next to the
  existing target frame.
- **Player portrait** — race/class portrait in the HUD panel. Art
  asset gated (portraits exist in `docs/concepts/lore/portraits/`).
- **EQ-style multi-window chat** — three chunks; biggest piece.

### Option C — Mount system design + implementation (~1.5 sessions)

The to-do list lists Mount as a precondition for Animal Husbandry,
Spirit of Wolf stacking, and Selos' Melody interactions. Design
sketch + client-side implementation; server-auth lift is the second
session if needed.

### Option D — Cross-cutting cleanups from Track 16/17 handoffs

Still open:
- **Soul Drain + Bind Affinity** not in server `spells.toml` — ~10
  lines of TOML to silence "unknown spell name" rejects.
- **Named-mob runtime loot has no .tres** — author ~15 .tres files
  from `data/named_mob_definitions.gd`; regen `items.toml`.
- **Destroy button "some items not others"** — playtest didn't
  produce a repro. If the user follows up, look at
  `bag_window._confirm_destroy` + `drag_source_*` state.

A whole session of small wins is also a legitimate session shape.

## Carry-forward from Track 18

- **L1 cap = starting score limitation** — fresh characters can't
  advance any skill until level-up grows the cap (`max_cap × level /
  60` is < starting for L1). This matches the GDScript pattern, but
  if playtest hates it the fix is to set `starting_value = cap / 4`
  (or similar) in both `skills.rs` and the three GDScript
  definitions, then mass-regenerate. Trivial change, just bulk.
- **Memorize cost client-only** — the server doesn't model the
  memorize bar. Forging a free memorize is harmless: cast still pays
  the full server-side gate (mana + cooldown + cast-time + movement).
  Lift only if there's a reason.
- **`save_unused` warnings in `connection.rs`** — `cast_start_pos`
  field added in 17.2, `weapon_skills` / `armor_skills` /
  `casting_skills` / `skills_dirty` in 18 — all are accessed
  via `super::skills` and `super::persistence` paths so the dead-
  code lint shouldn't fire, but verify on cargo check.

## Carry-forward beyond Track 19

- **Zone transitions** — server-side zone routing, world-token
  re-issue or re-handshake, position handoff, AOI grid per zone.
  Big track. Gated by content (currently one zone). When the
  second zone lands, this is the next major server lift.
- **PvP flagging** — design decision still pending (see the to-do
  list in `CLAUDE.md`). Alignment kill deltas exist; flagging
  trigger + consequences need a design call.
- **Corpse run** — gear stays on corpse, respawn naked, retrieve
  it. Optional hardcore mode. Design call first.
- **Incoming /tell RPC** — outbound is done; inbound needs a
  protocol message + chat-log render path.

## Known flaky tests

Same as Track 16-18 handoffs: `world_two_clients.rs` has 1-3
intermittent failures per full-suite run in the AI-walks-into-melee
timing tests:
- `lifesteal_spell_heals_caster`
- `player_attack_kills_enemy_and_corpse_despawns`
- `enemy_aggros_chases_and_attacks_player`
- `pet_pulls_aggro_via_threat_reaggro`
- `aoe_spell_damages_nearby_enemies`

All pass in isolation. Track 18's new tests (`skill_progress_*`)
are stable.

## Suggested first move

Commit the in-flight Track 16/17/18 work (or at least mark a clean
boundary with `git stash` + targeted re-applies if you want
separate commits per track) before starting Track 19. The diffs
have grown large enough that a `git status` walk-through is
painful.

Then check `docs/playtest_notes/` for any new files and let the
user's signal pick the Track 19 direction.
