# Track 23 Handoff — Multi-window chat or open scope

You're picking up Project Dawn. Track 22 (2026-05-24) closed
C/E/F/H/I across two commits. G (multi-window chat) is the only
remaining Track 22 menu item — and it's the biggest piece by far
(2-3 sessions across three sub-chunks).

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_24_track22C.md` — Mount
   system closeout.
3. `docs/session_notes/session_2026_05_24_track22_EFHI.md` —
   spell-damage interrupt + skill cap rebalance + peer→peer target
   broadcast + portrait slot closeout.
4. `docs/playtest_notes/` — check for new files after 2026-05-24.
5. `scripts/combat_log.gd` — current single-window chat. The
   multi-window framework grows from / replaces this.

## Four repos at handoff

| Repo | Path | Branch |
|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` |
| Server | `F:\Projects\server\` | `main` |
| Launcher | `F:\Projects\launcher\` | `main` |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` |

Track 22 batch uncommitted at handoff time — recommended first
move: commit C (mount) and EFHI (rest) as two separate commits
per repo for cleaner history.

## Recommended priority

### Top priority — Track 22 playtest verification

Before tackling G, walk through the changes from C/E/F/H/I in a
playtest run:
- Mount: `/give brown_steed_whistle`, right-click summon, take a
  hit, verify dismount log line + speed reset. `/dismount` chat
  command.
- Spell-damage interrupt: PvP scenario with two clients, one
  casts, the other casts a damage spell back. Verify CastFail
  arrives.
- Skill rebalance: fresh L1 character should see skill bars move
  with use (was previously stuck at cap).
- Peer→peer target: track a peer in PvP who is attacking
  someone. ToT frame should show that someone.
- Portrait: drop a test PNG at
  `assets/sprites/portraits/portrait_human_warrior.png` and verify
  it appears at the top-right of the stat panel for a Human
  Warrior character.

### Option G — Multi-window chat (~2-3 sessions across 3 chunks)

Per the to-do list in `CLAUDE.md`:

**G.1 — Multi-window framework**
- Create / rename / delete independent chat windows.
- Dock together as tabs in a parent window or detach to float.
- Persist layout to `user://chat_windows.json` or similar.
- `combat_log.gd` becomes one of N windows rather than the
  singleton. Or stays as the "default" window and others spawn
  alongside.

**G.2 — Per-window message filters**
- Right-click menu on a window → checklist of
  `CombatLog.MsgType` categories to display (Say, OOC, Group,
  Tell, Guild, Raid, Auction, damage dealt, damage taken, heals,
  system, pet actions, etc.).
- Each window has its own filter set.

**G.3 — Per-window display settings**
- Window alpha (0-100).
- Font alpha (10-100).
- Font size (9-21pt).
- Default channel for the input field when this window is active.

Single session per chunk roughly.

## Carry-forward beyond Track 23

From Track 22:
- **Portrait art generation** — run the prompts.md prompts in
  Gemini 3 Pro Image, save PNGs to
  `assets/sprites/portraits/`. Wiring is already in place.
- **Mount mesh / visual** — speed-only v1; player doesn't
  actually ride a model. Stretch goal: attach a mount mesh.
- **Server-auth mount state** — for peer visibility of mounted
  players. Optional.

From earlier:
- **L1 cap = starting score** — fixed in 22.F.
- **Memorize cost client-only** — server doesn't model the spell
  bar; forging a free memorize is harmless because casting pays
  the full server-side gate. Lift only with reason.
- **Zone transitions** — gated by content. When the second zone
  lands, this is the next major server lift.

## Known flaky tests

`world_two_clients.rs` has the documented AI-walks-into-melee
flake (1-3 intermittent failures per full-suite run; all pass in
isolation):
- `lifesteal_spell_heals_caster`
- `player_attack_kills_enemy_and_corpse_despawns`
- `enemy_aggros_chases_and_attacks_player`
- `pet_pulls_aggro_via_threat_reaggro`
- `aoe_spell_damages_nearby_enemies`
- `pet_command_attack_locks_onto_target`

Track 22 doesn't touch combat AI — these are pre-existing.

## Suggested first move

Commit Track 22.C and Track 22.EFHI separately. Then either run
the verification checklist or tackle G — your call. If G is
chosen, recommend starting with G.1 (framework) since G.2 and
G.3 are filters/styling that plug into the framework.
