# Track 17 Handoff — Memorize-cost gating + cooldown / cast server-auth

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Track 16 (2026-05-22) finished the classic spell-book → spell-bar
memorize workflow, the social/macro library tier, and five Track 15
UX regressions surfaced in the 2026-05-22 playtest. See
`session_2026_05_22_track16.md` for the full diff inventory.

Track 17 is the next step in the spell-pipeline tightening pass.
Two sub-tasks; the second is the carry-forward server-auth lift
from the Track 14 / 15 / 16 handoffs.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_22_track16.md` — Track 16
   closeout. The Memorize autoload pattern (new in 16.1) is the
   template if Track 17 needs more candidate-style state.
3. `docs/playtest_notes/testing_notes_2026_05_22.md` + any new
   `testing_notes_2026_05_2*.md` the user adds before Track 17
   starts.
4. `autoloads/spell_bar.gd` — new in 16.1, owns per-character
   memorize bar storage at `user://spell_bar.json`. Track 17.1's
   cost-gating reads from it.
5. `autoloads/memorize.gd` — new in 16.1, owns the spell-book →
   spell-bar candidate state. Sit-gating and auto-clear on stand
   already wired.
6. `autoloads/spells.gd` — `cast_spell(spell)` is the single entry
   point. `cooldowns` field already in place; Track 17.2 lifts the
   cooldown gate to server.
7. `crates/projectdawn-server/src/world/handlers.rs` — `CastSpell`
   arm. Track 17.2's cooldown reject + cast-time interrupt land
   here.

## Four repos at handoff

| Repo | Path | Branch |
|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` |
| Server | `F:\Projects\server\` | `main` |
| Launcher | `F:\Projects\launcher\` | `main` |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` |

Run `git -C <each> log --oneline -10` before touching anything.
Track 16 client + server changes are still uncommitted; read the
diff before starting.

---

## Sub-task 17.1 — Memorize cost + per-spell cap (~1 session)

Track 16 added the memorize workflow but free of charge. Classic
MMOs gate memorize behind a cost (mana spend + cast-time-style
animation) so it's a deliberate downtime activity, not "open book
mid-fight and reshuffle." This sub-task adds:

1. **Mana cost** for memorize — `SpellData.mana_cost * 0.5` debited
   from PlayerStats on a successful slot assignment. Fail-with-log
   if MP is short.
2. **Memorize cast bar** — 2-second visual progress reuses the
   existing `HUD.CastBar` widget. Movement / damage / standing
   cancels it (mirror the rules already in `Spells.cast_spell`).
3. **Memorize cap** — only N slots can be filled at once
   (N = `min(8, max(3, PlayerStats.level / 5))`). Slot 9–10 stay
   visually present but locked until level 25 / 40.

**Touchpoints:**

- `autoloads/spell_bar.gd` — new `MAX_SLOTS_FOR_LEVEL` function;
  `set_slot` rejects slot index >= cap.
- `autoloads/memorize.gd` — new `commit(slot: int)` verb that
  starts the cast bar + debits mana + writes through SpellBar.
  Move the slot-assignment write out of `hotbar.gd` so the new
  cost + cast checks live in one place.
- `scripts/hotbar.gd:_on_spell_clicked` — call
  `Memorize.commit(slot)` instead of `SpellBar.set_slot` directly.
- `scripts/hud_cast_bar.gd` — already takes a name + duration;
  reuse via `start_memorize_bar(spell, 2.0)` (or just reuse the
  existing `casting_started` signal path with a synthetic
  SpellData-like dict — pick the cleaner option in the moment).

**Edge cases:**

- Reassign an already-filled slot → charge again, replace.
- Server-auth lift on memorize cost? Probably not yet — Track 17
  keeps memorize client-side. The server doesn't model the spell
  bar; CastSpell still validates MP at the time of cast, so a
  forged "free memorize" doesn't translate into a forged cast.
- Memorize while moving (Track 16 only required sitting at
  click-time; if the player stood up mid-cast, the candidate
  cleared but the slot still wrote). With a real cast bar this
  becomes interruptible, matching classic feel.

---

## Sub-task 17.2 — Cooldown + movement-during-cast server-auth (~1.5 sessions)

This is the carry-forward from Track 14 / 15 / 16 handoffs. The
server already validates spell name + MP cost + cast-time gate
(Track 10). Two pieces still missing:

1. **Per-player per-spell cooldown map** on the server. Reject any
   `CastSpell` arriving before the cooldown expires. Today the
   server treats every cast as if cooldown were zero; a forged
   client could spam-cast.
2. **Movement-during-cast detection** on the server. Today the
   client cancels its own cast on movement, but a forged client
   that omits the cancel can keep the cast alive while moving. The
   server should compare caster pos at `cast_set_at` vs now in
   the gate; >1.0 m movement cancels.

**Touchpoints (server-side):**

- `crates/projectdawn-server/src/world/connection.rs` — add
  `cooldowns: HashMap<String, Instant>` on `PerConnection`.
  Spell-id keyed by name (matches the existing cast_spell_name
  pattern). Optional: `cast_start_pos: Vec3f` if not already
  cached for the cast-time gate.
- `crates/projectdawn-server/src/world/handlers.rs:CastSpell` —
  before the existing cast-time-gate check, look up the spell's
  cooldown from `spells.toml`, check `cooldowns.get(&name)`, and
  reject with `CastFail("on cooldown")` if not elapsed. After a
  successful cast, write `cooldowns.insert(name, now + cooldown)`.
- Cast-time gate already stamps `cast_set_at`. Add a position
  capture at that point (or reuse `pos` snapshot if the
  PerConnection already has one), compare on `CastSpell`, fan
  `CastFail("interrupted: moved")` and clear the cast cache.

**Tests:**

- New integration tests in
  `crates/projectdawn-server/tests/world_two_clients.rs`:
  `cast_rejected_during_cooldown`,
  `cast_rejected_when_caster_moved_during_cast`.
- Pre-existing AI-timing flakiness in `world_two_clients.rs` is
  carrying forward (see Track 16 handoff). Track 17 doesn't touch
  combat AI, so failures there are still pre-existing.

---

## Cross-cutting cleanups (small wins, if time)

These were called out in the Track 16 handoff and remain open:

- **Soul Drain + Bind Affinity** not in server `spells.toml` —
  ~10 lines of TOML to silence the "unknown spell name" rejects.
  See `crates/projectdawn-server/data/spells.toml`.
- **Named-mob runtime loot has no .tres** — Chitinous Ring, Pristine
  Venom Sac etc. live as inline dicts in
  `data/named_mob_definitions.gd`. Author ~15 `.tres` files and
  regen `items.toml`.
- **Destroy button "some items not others"** — user May 21 note
  with no repro yet. If the user follows up with which items, look
  at `bag_window._confirm_destroy` and the `drag_source_*` state.
- **Pet command stickiness UI** — server has 30 s sticky window for
  ATTACK; nothing on the client surfaces this. A 30 s ring around
  the pet stance icon would close the "did my command land?" gap.

---

## Carry-forward from Track 16

Track 16 closed the spell-book / spell-bar UX lift. The remaining
client-side polish items:

- **Memorize bar reset on death / zone change** — Track 16 wired
  the candidate clear on player-stands-up, which DOES fire on
  respawn (death drops to STANDING). Confirm on first playtest
  before assuming it's covered.
- **Bag windows persistent open** — nice-to-have UX so opened bags
  stay open across reconnect. Stored in `user://ui_state.json`
  alongside the existing panel positions.
- **Target-of-target frame** — still open from the original
  UI-polish to-do list.
- **Player portrait** — still open.

---

## Known flaky tests

Same as Track 16 handoff: `world_two_clients.rs` has 1–3
intermittent failures per full-suite run in the AI-walks-into-melee
timing tests. Track 17.2's new tests use the cast pipeline (not the
AI loop) so they should be stable.

---

## Pick one and write the next handoff

Recommended start: **17.1 memorize cost + cap.** Smaller lift,
unblocks the playtest's "is memorize the right rhythm?" question
before the server-auth pieces land. 17.2 (cooldown + cast-move
auth) is the closure of the Track 10 trust-model story and can
ship as a follow-up commit on the same branch.

If you have time after 17.1 + 17.2, the cross-cutting cleanups
(Soul Drain TOML, named-mob `.tres`, destroy button repro) close
visible gaps in the playtest log.
