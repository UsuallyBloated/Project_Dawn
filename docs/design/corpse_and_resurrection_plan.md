# Corpse System + Cleric Resurrection: Implementation Plan (kickoff for a fresh session)

You are implementing the EverQuest-style **corpse run** (gear stays on your body, respawn naked,
travel back to loot it) and **Cleric resurrection** in Project Dawn. This document is self-contained.
The design forks below were locked with the user on 2026-06-20; do not re-litigate them.

This is an **epic**, not a single feature. It is sliced so you can ship value incrementally and stop
between slices for the user to playtest (their usual flow). Slice 0 is a real prerequisite; read
section 3 before promising Slice 1.

---

## 0. Orientation (read before touching code)

Project Dawn is a **multiplayer-only** MMORPG: a Godot 4.4 GDScript client
(`F:/Projects/Project_Dawn`, this repo) and a Rust authoritative server (`F:/Projects/server`). They
share a wire protocol (`crates/protocol`) bridged into the client by the `gdext_net` GDExtension DLL.

Constraints a fresh session WILL trip on (same ones the camp/linkdead track hit, see
`docs/design/camp_and_linkdead.md`):

- **Run server cargo from `F:/Projects/server`.** The toolchain is pinned (rust 1.95.0) by
  `rust-toolchain.toml`; running from elsewhere silently picks the wrong rustc.
- **Append-only enums.** bincode encodes enum variants by position. Any new `ClientWorldMsg`,
  `ServerWorldMsg`, or `KickCode` variant MUST be appended at the END of its enum.
- **Bump `WORLD_PROTOCOL_ID`** in `crates/protocol/src/world.rs` on any wire change (it is **PD_W0017**
  now, so go PD_W0018, PD_W0019, ... one bump per wire-changing slice). After any protocol or gdext
  change, **rebuild the DLL**: `addons/gdext_net/build.ps1` (about 45 to 60s, run it plainly, no
  `2>&1`). The DLL is gitignored.
- **gdext cannot encode tagged enums from the GDScript client.** Keep any client-to-server message to
  primitives/strings (the loot system already does this: `LootItem { bag_id, slot }`).
- Server logs to **stdout** (no log file). Capture with `... | Tee-Object server.log`. Run with dev
  commands enabled: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server`. `server.log` and `*.exe`
  are now gitignored in the server repo.
- **Do not modify anything above `F:/Projects/`.**
- Style: the user dislikes em-dashes and the arrow glyphs; use plain punctuation and words like "to".
  Match the comment density and idiom of the surrounding code.

Build / verify commands:

- Server tests: `cargo test -p projectdawn-server --lib` (from `F:/Projects/server`, ~30s).
- Server build: `cargo build -p projectdawn-server`.
- DB migrations: SQLite `world.db`, `sqlx` auto-applies migrations from `migrations/` on boot. A new
  table needs a new `migrations/000X_corpses.sql`.
- Client boot check (0 errors): `"F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --path f:\Projects\Project_Dawn --quit` and confirm no `SCRIPT ERROR` / `Parse Error`. Note: the lobby is the boot scene, so this does NOT compile the in-game HUD; to validate `hud.gd` and other world-scene scripts, run `--headless --editor --quit` instead (the editor registers autoloads and compiles every script; grep its output for `Identifier not found|Compile Error|Parse Error|SCRIPT ERROR`).
- Live debugging: the in-game debug console (backtick) tails `DebugLog`.

---

## 1. The model (LOCKED with the user 2026-06-20, do not change)

Full hardcore EverQuest corpse model. The four core forks, as the user chose them:

- **Gear stays on the corpse.** On death your gear (everything equipped PLUS everything in your bags)
  is moved onto a lootable **corpse** that sits where you died. You respawn **naked** at your bind
  point and must travel back to loot your body. This is the corpse run.
- **XP loss on death, and you can de-level.** Death costs a chunk of XP and can drop you a level. A
  Cleric resurrection restores most of the lost XP (see below). This makes a res valuable.
- **Harsh decay.** The corpse persists a long time (survives a server restart) but eventually
  **decays**, and any gear you did not retrieve is **gone for good**. Maximum stakes.
- **Full EQ Cleric resurrection.** A Cleric spell targets a corpse, returns the dead player to it,
  restores a percentage of the LOST xp (tiered per spell, see section 6), and applies a short
  **res-sickness** debuff.

These layer on top of the already-shipped death penalty (a 5% XP loss) and the linkdead/camp logout
system. Note the linkdead design explicitly deferred "corpse interactions for a killed linkdead
character" to this track: a player killed while linkdead (or after release) leaves a corpse the same
way; nothing special is needed beyond making corpse-creation server-authoritative (Slice 0).

**Session decisions locked 2026-06-22 (these resolve the open forks below; do not re-litigate):**

- **Slice 0 scope: the full server-authoritative XP/leveling port** (NOT the minimal death-delta
  fallback). The server owns xp AND level-ups and fans a `LevelUp` the client mirrors; this closes the
  level-up desync drift as part of Slice 0.
- **Death XP penalty: 5% of the current level's XP band** (`xp_to_next`), per death. Today's client
  loss is 5% of progress *into* the level and clamps at 0 (`player_stats.gd` `lose_xp`), so it never
  de-levels; the server model instead bites 5% of the whole band and lets the loss **underflow past the
  level boundary and cascade with no per-death cap**, so repeated deaths keep de-leveling you.
- **Grace + floor: level 5.** Deaths cost no XP at levels 1 to 4; the penalty applies only at level 5+,
  and no cascade can ever drop a character below level 5 (the safe-zone line and the de-level floor are
  the same line).
- **Coins: stripped onto the corpse** with gear (banked coin stays safe), and they decay with the
  corpse if unretrieved.
- **Cleric res percentages unchanged:** 25/50/75% of that death's LOST xp restored, per tier.

---

## 2. What already exists (do NOT rebuild) — grounded pointers

### The corpse skeleton: the LootBag system (`F:/Projects/server`)
`world/loot.rs` `LootBag` is almost exactly a corpse: a server-owned container with `items:
Vec<LootItemStack>` + `coins`, an `owner_killer: Option<ClientId>` with `can_loot(looter, groups)`
loot-rights, an id minted in the reserved partition, and a decay timer. Reuse its shape.
- Id partitions (`protocol/world.rs:1179-1189`): `< ENEMY_ID_BASE (1e9)` player, `< LOOT_BAG_ID_BASE
  (2e9)` enemy, `< PET_ID_BASE (3e9)` loot bag, `>= 3e9` pet. The client routes Position/EntityDespawn
  by id alone. **Decide:** mint corpses inside the loot-bag partition (cheapest; the client already
  renders + loots bags) versus a new corpse partition. Recommended: reuse the loot-bag partition and
  distinguish a corpse with a dedicated spawn message (so the client shows a body + nameplate, not a
  sack), OR a flag on the spawn payload.
- Loot wire (`protocol/world.rs`): `ClientWorldMsg::LootItem { bag_id, slot }` / `LootAll { bag_id }`;
  `ServerWorldMsg::LootBagSpawn { bag_id, ... }` / `LootGranted { item_path, count }` (private to the
  looter) / `LootRejected { reason }`; despawn via `EntityDespawn`. Loot intent handlers + the
  dispatch live in `world/tick.rs` (grep `LootItemIntent` / `LootAllIntent` / `loot_intents`).
- Decay: `LOOT_BAG_LINGER_SECS = 120.0` (`world/mod.rs`); the expiry sweep is in `tick.rs` (grep
  `expired_bags`). Corpses need their own much longer, tunable `CORPSE_LINGER_SECS` and an analogous
  sweep that ALSO deletes the persisted rows.
- **The gap a corpse adds over a loot bag:** loot bags are in-memory only (`HashMap<EntityId,
  LootBag>` in `tick::run`). A corpse must **persist** (a server restart during someone's corpse run
  must not delete their gear) and own a long decay. So a corpse needs a DB table, not just a map entry.

### Inventory + equipment + persistence (`F:/Projects/server`)
`world/inventory.rs` `PlayerInventory` holds `equipment: HashMap<u8, InventoryEntry>` (the paperdoll)
plus base slots + bags; helpers `to_rows()` / `from_rows()` / `to_snapshot_entries()` /
`destroy_at()` / `add_item()`. Persistence in `db/mod.rs`: `load_inventory(pool, char_id)` reads
`character_items` (char-keyed: `location`, `slot`, `item_path`, `count`); `save_inventory(pool,
char_id, rows)` does a full DELETE+INSERT. Resources/xp/level persist via `checkpoint_resources`.
- To "strip gear to corpse, respawn naked" you must: (1) snapshot ALL of `equipment` + base + bag
  entries into the corpse, (2) clear the live inventory + equipment (and re-run
  `recompute_equipped_stats` so the naked body loses its gear stat bonuses), (3) persist BOTH the
  corpse rows AND the now-empty `character_items` in the SAME pass, (4) on retrieval move items back +
  re-persist. **Dupe/loss risk:** the corpse and the cleared inventory must be persisted atomically;
  if the server saves the empty inventory but not the corpse (or vice versa), a restart dupes or
  vaporizes the gear. Persist corpse-side first, then clear+persist the player, and make corpse load
  happen at server boot before any login can loot.

### Death / respawn / XP today is CLIENT-DRIVEN (the big architectural gap)
- `autoloads/player_death.gd` (client): detects death locally on `hp_changed` to 0, loses **5% XP
  client-side** (`XP_LOSS_PERCENT`, `PlayerStats.lose_xp`), calls `Net.broadcast_death()`, runs a 5s
  `RESPAWN_DELAY`, then `Net.broadcast_respawn()` and travels to the **bind** (`PlayerStats.
  bind_zone_path` / `bind_entry_id` / `bind_zone_name`) or a fallback `_respawn_position`.
- Server `ClientWorldMsg::DeathBroadcast` (`handlers.rs`, ~526) just zeroes `conn.hp`, clears
  cast/buffs (and now `camp_since`), fans `EntityDied`. `ClientWorldMsg::Respawn` (~670) only resets
  hp/mp/stamina to weakened multipliers; **it does NOT relocate the player** (no server bind point).
  The handler's own comment says "Sub-task 3 lifts the timer + multipliers fully server-side."
- **Leveling + max stats are client-local and provisional** (see `systems_overview.md` known-drift +
  the [[project-level-up-server-desync]] memory): the server stores xp/level but the client drives
  level-ups, and a stale server `HealthUpdate` can roll a fresh level-up back. So **XP loss with
  de-level cannot be authoritative until XP/leveling is server-authoritative.** This is why Slice 0
  exists. **Confirmed 2026-06-22:** `xp` is progress INTO the current level (it resets to the remainder
  on level-up), `xp_to_next` is the band size (grows x1.5/level), and `lose_xp` clamps at 0, which is
  exactly why today's penalty cannot de-level. The server cascade must remove that clamp.

### Cleric resurrection is designed, not wired
`docs/concepts/classes/cleric.md` defines a tiered res keyed to the Restoration casting skill:
`Resurrection (Minor)` (req 80, **25% XP returned**), `Resurrection` (req 100, **50%**),
`Resurrection II` (req 130, **75%, instant cast**), each "Revive dead ally at corpse." Interpret the
percentage as **% of the XP LOST on that death restored** (EQ semantics), not % of total xp. Before
building Slice 3, grep `data/spell_definitions.gd` and the server `spells.toml` for any existing
`Resurrection` entries (they may be authored but inert) and reconcile (spells live in BOTH and drift,
see [[project-warders-mend-server-spell-gap]]). **Confirmed 2026-06-22:** exactly ONE inert
`Resurrection` placeholder exists (`spell_definitions.gd`: `min_level 20`, `target_type NONE`, mana
200, 10s cast), and it is keyed to the **alteration** discipline on BOTH the client `DISCIPLINE` map
and the server `skills.rs`, NOT the **Restoration** skill the cleric.md tiers use. Slice 3 must author
the three tiers (`Resurrection (Minor)` / `Resurrection` / `Resurrection II`, reqs 80/100/130) and move
them onto Restoration on both sides.

### Bind points do not exist server-side
The client has a bind (`PlayerStats.bind_zone_path`), but there is no Soul Binder NPC and no
server-authoritative bind. Slice 0/1 must decide whether to (a) honor the client's bind for the naked
respawn for now, or (b) add a server bind. Recommended for v1: honor the existing client bind, and add
a Soul Binder NPC + server bind as a later polish.

---

## 3. Slice 0 (PREREQUISITE): server-authoritative death + XP/leveling

> **STATUS: BUILT 2026-06-22, awaiting the user's playtest (not committed).** Implemented in
> `server/crates/projectdawn-server/src/world/progression.rs` (+ `tick.rs` death sweep, `handlers.rs`,
> `connection.rs`, wire PD_W0018) and the client (`player_stats.gd` `apply_server_level` /
> `apply_remote_xp`, `net.gd`, `quest_manager.gd`, `player_death.gd`). 143 lib tests + the kill-credit
> integration test green; clean editor boot. See `docs/session_notes/session_2026_06_22.md` and the
> playtest checklist `docs/playtest_notes/corpse_slice0_checklist.md`. Slice 1 starts after it
> verifies clean.

Goal: the SERVER decides death, applies the XP loss + de-level, and resets resources on respawn, so
the corpse-spawn and XP penalty in Slice 1 are authoritative and cannot be cheated or rolled back.

This is the riskiest, least flashy slice and it touches the leveling drift directly. Scope it tightly:

1. **Server-authoritative XP/level.** Port the level curve + XP-to-next so the server owns xp/level
   (it already stores them). Stop the client from being the source of truth for level-ups; fan a
   server `LevelUp` / xp update the client mirrors. This closes [[project-level-up-server-desync]] and
   is the gate for an authoritative death penalty. (LOCKED 2026-06-22: do the full port, not the
   minimal death-delta fallback.)
2. **Server detects death.** Combat already reduces `conn.hp` to 0 server-side (the 5 player-damage
   sites the camp track hooked). When a player's hp reaches 0 server-side, the server runs a
   `kill_player(conn)` path: apply the XP loss (a tunable % of the xp needed for the current level,
   EQ-style, capable of de-leveling), reset the post-respawn resources, and (Slice 1) spawn the
   corpse. Keep the client's `DeathBroadcast` working during the transition but make the server path
   the authority (the client's local 5% becomes display-only / removed).
3. **Respawn.** Decide client-driven-at-bind (honor the existing flow) vs server-authoritative respawn
   location. v1 recommendation: server resets resources + (Slice 1) confirms the naked inventory; the
   client still travels to bind. Add a server respawn point later with the Soul Binder.

**Death cost (LOCKED 2026-06-22, see the locked-decisions block in section 1):** a death costs **5% of
the current level's XP band** and the loss **cascades past the level boundary with no per-death cap**;
**no penalty below level 5, hard de-level floor at level 5**; a Cleric res restores 25/50/75% of that
death's lost xp by tier. No skill/AA loss.

**Stop and report after Slice 0.** It is invisible to the player but it is the foundation. Verify:
xp/level survive death + relog correctly; a death de-levels at the right threshold; `cargo test
-p projectdawn-server --lib` green.

---

## 4. Slice 1: the corpse entity (the corpse run)

> **STATUS: BUILT 2026-06-23, awaiting the user's playtest (not committed).** Wire PD_W0018 to
> PD_W0019. Server: migration `0007_corpses.sql`, `world/corpses.rs`, `db::{save,load,delete}_corpse`,
> `inventory::{all_stacks,clear_all}`, the atomic gear move in the `tick.rs` death sweep, corpse decay +
> boot-load + AOI seeds, `CorpseSpawn` + `fan_out_corpse_spawn`. Client: `scripts/corpse.gd`,
> `autoloads/remote_corpse_manager.gd`, `net.gd` wiring, death combat-log line. 143 lib tests + the
> migration integration test green; clean editor boot; DLL rebuilt. See
> `docs/session_notes/session_2026_06_23.md` and `docs/playtest_notes/corpse_slice1_checklist.md`.
> Retrieval (looting your own corpse) is Slice 2.

Goal: dying leaves a persisted corpse holding your gear; you respawn naked; the corpse is visible with
a nameplate and decays (harshly) if unretrieved. (Retrieval is Slice 2.)

1. **Persistence.** New migration `migrations/000X_corpses.sql`: a `corpses` table (corpse_id PK,
   owner char_id, zone, x/y/z, created_at) + a `corpse_items` table (corpse_id, location, slot,
   item_path, count) mirroring `character_items`. DB helpers in `db/mod.rs`: `save_corpse`,
   `load_corpses` (ALL corpses, called once at server boot before logins), `delete_corpse`.
2. **Corpse on death** (extends Slice 0's `kill_player`): collect the player's full equipment + base +
   bag entries into a corpse container at `conn.pos`; clear the live `inventory` + `equipment` and
   re-run `recompute_equipped_stats`; persist the corpse, then persist the emptied `character_items`;
   insert the corpse into the in-memory corpse map + the AOI grid; fan a corpse spawn to AOI peers and
   the emptied inventory snapshot to the owner. Mirror `LootBag` but persisted and owner-only.
3. **Wire (bump to PD_W0018).** Append a `ServerWorldMsg::CorpseSpawn { corpse_id, owner_id,
   owner_name, x, y, z }` (or reuse `LootBagSpawn` with a corpse flag) so the client renders a body +
   "<name>'s corpse" nameplate. The owner's naked state goes out as the existing inventory snapshot.
   Add gdext decode + a signal (mirror an existing simple `ServerWorldMsg`); rebuild the DLL.
4. **Decay (harsh).** `CORPSE_LINGER_SECS` (tunable; long in prod, short for testing) in `world/mod.rs`;
   a corpse sweep in `tick.rs` (mirror `expired_bags`) that, on expiry, fans `EntityDespawn`, removes
   from the map + AOI, and **deletes the corpse + its items from the DB** (the gear is lost). Log it.
5. **Client.** Render a corpse entity (a `RemoteLootBag`-like manager, or extend
   `RemoteLootBagManager`) with a corpse mesh + nameplate; the player respawns naked (the inventory
   snapshot already drives this). No looting yet (Slice 2). Surface "You have died." + where your
   corpse is, in the combat log.

**Stop and report after Slice 1.** Verify (one client + a mob, dev `PD_DEV_CMDS=1`): die to a mob, see
the corpse appear at the death spot with your name, respawn naked at bind, relog and the corpse is
still there (persistence), let the (short test) decay timer elapse and confirm the corpse + gear are
gone from the world AND the DB.

---

## 5. Slice 2: corpse retrieval (loot your own corpse)

> **STATUS: BUILT 2026-06-23, awaiting the user's playtest (not committed).** Wire PD_W0019 to
> PD_W0020. Reuses `LootItem`/`LootAll` keyed by corpse id (no new client intent); new owner-only
> `CorpseContents` message; owner-only loot, gear to bags, coins 100% to owner; atomic
> `db::apply_corpse_loot` (one tx); **a LOOTED-empty corpse despawns, a naked-death empty corpse
> lingers** (res anchor). Client: `corpse.gd` is now a clickable `Area3D` driving the shared loot
> window. 143 lib tests green; clean boot; DLL rebuilt. See `docs/session_notes/session_2026_06_23.md`
> + `docs/playtest_notes/corpse_slice2_checklist.md`. NOTE: the plan's "despawn when empty" below is
> superseded for the naked-death case by the res-anchor decision (only a LOOT action despawns).

Goal: walk back to your corpse and get your gear.

1. **Loot rights.** A corpse is owner-only (unlike a group-shared mob bag): `can_loot` returns true
   only for the owner char (consider allowing group-mates to *drag* but not loot, later). Reject
   others with "That is not your corpse."
2. **Reuse the loot path.** `LootItem` / `LootAll` against the corpse id move items back into the
   owner's inventory (re-persist `character_items`), fan `LootGranted`, and re-persist/shrink the
   corpse; when the corpse is empty, despawn it + `delete_corpse`. Equipment that was stripped returns
   to the bags (the player re-equips manually), matching EQ.
3. **Client.** Reuse the loot window against the corpse. A proximity gate (the existing
   `LOOT_PICKUP_RANGE`) already applies.

**Stop and report after Slice 2.** Verify: die, run back, loot all, gear is back (no dupe, no loss),
corpse despawns and its DB rows are gone; a second player cannot loot your corpse.

### Fold in here: monsters leave a corpse too (user direction 2026-06-23)

The golden loot-bag orb is a placeholder; **everything that dies should leave a corpse, not a sack**.
Slice 2 is the natural place to unify, because corpse-looting makes a corpse a lootable container,
which is exactly what a monster's `LootBag` already is. One "lootable corpse" path: player corpses
persist + decay slowly + owner-only; monster corpses stay transient (`LOOT_BAG_LINGER_SECS`) +
group-loot-rights + loot-rolled. Decisions locked with the user:

- **Monster corpse visual: a generic body now; eventually the same model/scale as the creature that
  died** (so a dead ogre leaves an ogre-sized body). Generic placeholder first, per-creature later.
- Likely the cleanest mechanism: render the existing `LootBag` as a body (reuse the corpse mesh) and/or
  route monster deaths through a transient corpse variant; keep the loot mechanics. Carry the mob name
  on the spawn so the nameplate can read "a <mob>'s corpse" / "remains".

---

## 6. Slice 3: Cleric resurrection

Goal: a Cleric can res a dead player at their corpse, returning XP and saving the run.

1. **Spell.** Reconcile/author the tiered `Resurrection` spells in `data/spell_definitions.gd` AND
   server `spells.toml` (25/50/75% of LOST xp restored; the Restoration casting-skill reqs from
   cleric.md). The spell targets a CORPSE entity (a new target class for the cast gate).
2. **Flow.** The dead player must be "awaiting res" (in EQ you can wait as a corpse or release to bind;
   here, since you already respawn naked at bind on death, res should summon the *living, naked*
   player back to their corpse and refund the XP). Decide and document this; the simplest v1: a Cleric
   casts Resurrection on a corpse; the corpse's owner (if online) gets a res offer (a wire prompt);
   on accept, the player is moved to the corpse position, the corpse's gear is auto-returned (or they
   loot it normally), and X% of the death's lost xp is refunded server-side.
3. **Res sickness.** A short debuff (reduced stats/regen for a few minutes) applied on accept. Reuse
   the server buff system (`active_buffs`).
4. **Wire (bump again).** A `Resurrect` intent (cast already exists; you mainly need the corpse-target
   gate + a res-offer/accept message), the XP refund, and the sickness buff.

**Stop and report after Slice 3.** Verify two-client: A dies, B (Cleric) reses A's corpse, A accepts,
A is at the corpse with XP refunded and res-sickness, gear recoverable.

---

## 7. Cross-cutting / things to surface at build time

- **Atomicity of the gear move** (Slice 1/2): persist corpse-then-clear-player; load corpses at boot
  before logins. The single biggest dupe/loss risk.
- **Linkdead/camp interaction:** a player killed while linkdead leaves a corpse via the same
  server-authoritative `kill_player` path (Slice 0 makes this free). Confirm a linkdead body that dies
  drops a corpse and reaps cleanly.
- **Encumbrance/weight:** a naked respawn has no gear weight; re-looting restores it. The existing
  `Encumbrance` recompute should just work, but verify.
- **Coins on the corpse (LOCKED 2026-06-22):** death strips the carried wallet onto the corpse
  alongside gear; unretrieved coin decays with the corpse. Banked coin is never touched. Reuse the
  `LootBag.coins` field the corpse shape already inherits.
- **Bank is safe:** banked items/coins (Banker NPC) are never on the corpse. Confirm.

## 8. Out of scope for v1 (note, do not build)

- Soul Binder NPC + a server-authoritative bind (v1 honors the client bind).
- Necro corpse summon + corpse drag by group-mates.
- Corpse decay returning gear (the user chose harsh loss, so unretrieved gear is gone).
- Multiple corpses / corpse stacking edge cases beyond "one corpse per death."

## 9. Wrap-up (when slices land)

- One server commit + one client commit per slice (stage explicit files; the server repo has stray
  `.exe`/`server.log`, now gitignored, but double check). End commit messages with
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Docs: move the corpse-run + Resurrection items out of the CLAUDE.md to-do as they ship; add "what
  exists" to `docs/concepts/architecture/systems_overview.md`; dated session notes; a playtest
  checklist per slice from `docs/playtest_notes/TEMPLATE_checklist.md`.
- The user playtests between slices. Do not commit until they have verified. A `/code-review` pass is
  worthwhile each slice (this touches death, inventory/persistence, combat, and the wire).
- Recommended working style (matches the camp/linkdead build): a read-only recon workflow to map the
  exact integration points before each slice, then implement, then an adversarial multi-dimension
  review workflow over the diff before handing off.
