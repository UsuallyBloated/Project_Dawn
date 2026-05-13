# Track 6 Handoff — Server-authoritative player stats + PvP HP

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
companion Rust server (auth WS + world UDP), Godot launcher,
standalone procedural dungeon generator. Four repos, four branches.

Tracks 1–5 closed the server-authoritative loop for **player visibility
and enemy state**. Today two `.exe` instances on one server see each
other walk, render HP/MP/Stamina/buffs/casts in target frames, watch
each other die and respawn, see the same enemies in the same positions
fighting the same fights, pick up loot from server-broadcast bags with
FFA arbitration, and the killer (top damager) is the only client that
receives XP.

The wire format is stable at `WORLD_PROTOCOL_ID = PD_W0004`. Every
ClientWorldMsg / ServerWorldMsg variant relevant to player identity,
resource broadcasts, cast bars, buff snapshots, hit/miss/evade
floating text, enemy spawn / position / HP / death / loot / kill
credit is wired end-to-end.

**Track 6 is server-authoritative player stats + PvP HP.** Today the
client is authoritative on own HP/MP/Stamina (Track 4 broadcasts are
fan-out only — the server caches and relays, doesn't store as truth).
PvP hit/miss/evade broadcasts are pure visualization — peers see
floating numbers but their HP doesn't change. Damage formula is
computed client-side and trusted by the server (Track 5 sub-task 3's
Attack intent carries `amount: i32` which the server applies as
given). Player stats (STR/AGI/INT/WIS/CON/CHA, max HP/MP/Stamina,
weapon skill levels) live in `autoloads/player_stats.gd` and are
DB-loaded at character creation but never re-read by the server in
combat.

Track 6 lifts these:
- **Player resources move server-side.** Server caches HP/MP/Stamina
  per `PerConnection` (already in place from Track 4) but promotes
  the cache to the source of truth. `ClientWorldMsg::ResourceUpdate`
  becomes a *request* not a *broadcast*, or is deprecated entirely
  in favor of server-driven `HealthUpdate` / `ManaUpdate` /
  `StaminaUpdate` fan-out.
- **Damage formula moves to Rust.** Server reads stats from DB at
  spawn, applies STR/DEX/skill bonuses, rolls hit/miss/crit, applies
  HP delta. Client's `Combat.calc_damage` becomes prediction-only
  (for UI snappiness) — the server's outcome is truth.
- **PvP HP application.** Track 4's Hit broadcast carries `amount`;
  Track 6 actually deducts that from the target's server-side HP and
  fans out the new `HealthUpdate`.
- **Group XP migrates onto renet.** `GroupManager.distribute_kill_xp`
  uses the legacy enet MultiplayerAPI path today; Track 5 sub-task 5
  punted on this by only handling solo. Track 6 moves it onto
  the renet world channel so the server can split XP among the
  damagers it has on file.

After Track 6, two `.exe` instances can:
- Duel each other (within whatever PvP flag system you wire — see
  Open Question 4).
- See their own HP/MP/Stamina driven by server state, with the local
  HUD reading PlayerStats which is now a cache of server truth.
- Receive correct level-ups when the server's authoritative XP grant
  pushes them past the threshold.
- Share group XP correctly when grouped via the renet path.

After Track 6, only AOI / zone partitioning and the auction/social
systems remain before the netcode is "feature complete" for an
alpha-quality MMO.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `b02e1c9` (Track 5 sub-task 5: receive server XpGained and apply locally) |
| Server | `F:\Projects\server\` | `main` | `ff49666` (gdext-net: track 5 sub-task 5 — XpGained signal) |
| Launcher | `F:\Projects\launcher\` | `main` | `18da871` (protocol.gd: add SW_ENEMY_SPAWN / SW_ENTITY_TARGET tags (mirror)) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS into DEBUG_TORCH_LABELS / DEBUG_COMPASS) |

Run `git -C <each> log --oneline -5` before touching anything to
confirm the state still matches.

## Read these in order

1. `F:\Projects\Project_Dawn\CLAUDE.md` — project conventions,
   autoload map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_13.md`
   — Track 5 close. The five sub-tasks landed the
   server-authoritative-enemy pattern; Track 6 lifts the same
   pattern to player state.
3. `F:\Projects\server\crates\protocol\src\world.rs` — read the
   full `ClientWorldMsg` and `ServerWorldMsg` enums. The
   `ResourceUpdate` (client→server broadcast) and `HealthUpdate` /
   `ManaUpdate` / `StaminaUpdate` (server→client fan-out) shapes
   already exist from Track 4. Track 6 inverts the authority:
   server becomes the source of truth, client sends *requests*
   (Sit/Stand/Cast/etc.) and the server emits updates.
4. `F:\Projects\Project_Dawn\autoloads\player_stats.gd` — the
   stat / resource / level / XP entry points. Today these are
   freely mutable; Track 6 either gates every setter behind a
   "server-driven only" flag in launcher mode, or splits
   PlayerStats into a Test-Room-authoritative copy and a
   server-driven-cache copy.
5. `F:\Projects\Project_Dawn\autoloads\combat.gd` — the damage
   pipeline. `_on_auto_attack` already routes through
   `_apply_damage_to_node` to pick the authority per target
   (RemotePlayer → broadcast, RemoteEnemy → server, local Enemy →
   take_damage). Track 6 changes RemotePlayer to a different
   broadcast that the server processes as authoritative, not
   visual-only.
6. `F:\Projects\server\crates\projectdawn-server\src\world\connection.rs`
   — `PerConnection.last_hp / last_max_hp / last_mp / ...` already
   caches resources for fan-out. Track 6 makes these the authority:
   server reads from DB at spawn, mutates on damage / heal / regen
   tick, broadcasts on every change > threshold (or on a clock).
7. `F:\Projects\server\crates\projectdawn-server\src\world\tick.rs`
   — Track 6 adds a regen tick phase (HP/MP/Stamina recovery), a
   PvP-Hit-application phase (deduct HP from target_id when the Hit
   is between two players), and possibly a death-detection phase
   for players (HP ≤ 0 → DeathBroadcast equivalent driven from
   server side rather than from a client send).
8. `F:\Projects\Project_Dawn\autoloads\regen.gd` — current
   HP/MP/Stamina regen lives client-side, with sit-bonus + food/
   drink stacking. The math moves to Rust; client's regen.gd
   becomes inert in launcher mode (or routes through Net to send
   a Sit/Stand intent and let the server's regen rate change).
9. `F:\Projects\Project_Dawn\autoloads\group_manager.gd` —
   `distribute_kill_xp` uses Godot's enet MultiplayerAPI. Track 6
   migrates onto the renet world channel: server has the group
   roster (new state to add), tallies aggro across all group
   members, splits XP server-side.
10. `F:\Projects\server\crates\projectdawn-server\src\db.rs` —
    `CharacterSpawn` loads pos/yaw/zone/name/race/class/level.
    Track 6 extends it with full stats (STR/AGI/INT/WIS/CON/CHA),
    resources (HP/max_HP/MP/max_MP/Stamina/max_Stamina), and
    weapon skill levels for the authoritative combat math.

---

## Current reality (as of Track 5 close, 2026-05-13)

### What works end-to-end

- **Tracks 1–4** (player visibility + identity).
- **Track 5** (server-authoritative enemies + loot + kill credit):
  enemies spawn / AI / die / loot / respawn all server-driven.
  Solo XP awarded to top damager on every kill.
- **Trust model (current).** Client owns own HP/MP/Stamina. Server
  trusts client-supplied `amount` in attack intents (against
  enemies). PvP broadcasts are visual-only.

### What's missing for server-authoritative combat

- **Player HP lives client-local.** A client could trivially edit
  PlayerStats and become unkillable. Acceptable for an alpha but
  not for any actual PvP / leaderboard / economic system.
- **Damage formula lives in GDScript.** `Combat.calc_damage` reads
  STR / weapon damage / skill levels from PlayerStats and sends the
  result. Track 6 mirrors the formula in Rust; client computes
  predictively for UI, server computes authoritatively for state.
- **No regen on the server.** HP/MP/Stamina recovery is purely
  client-side; the server has no tick logic for it.
- **No DB-loaded player stats.** Track 5 added MobTemplate xp /
  hp / dmg in `data/zone_camps.toml`; the server has nothing
  equivalent for players. Stats are picked at character creation
  in the launcher but never round-tripped through the world server.
- **PvP HP application.** Hit broadcasts fan out visually; no HP
  deduction happens server-side or on the target client.
- **Group XP via renet.** Track 5's kill credit is solo only.
  GroupManager is on the legacy enet MultiplayerAPI which doesn't
  cross the renet boundary.

### Hard layout invariants you must preserve

- `F:\Projects\Project_Dawn\scripts\net\protocol.gd` stays 1:1
  with `F:\Projects\launcher\scripts\net\protocol.gd`. Any new
  tag constants are mirrored in the same session.
- `addons/gdext_net/gdext_net.dll` is gitignored. Rebuild via
  `cargo build -p gdext-net --release` + Copy-Item.
- The Rust `protocol` crate is canonical. `WORLD_PROTOCOL_ID`
  bumps on any wire-format break. Track 6 bumps once for the
  whole batch (`PD_W0004 → PD_W0005`).
- `PROJECTDAWN_NETCODE_KEY` is sacred. Never logged, committed,
  or in test fixtures.
- **Re-export the game** after any GDScript / scene / DLL change
  before multi-instance testing.
- `scripts/enemy.gd` is on the no-modify list. Track 5 already
  built `scripts/remote_enemy.gd` as the launcher-mode render-only
  parallel; touch only that.

---

## Track 6 scope

Five sub-tasks, in order. Sub-task 1 is the big architectural piece
(load stats from DB into PerConnection, switch authority); the rest
build on it.

### Sub-task 1 — DB-loaded player stats + server-cached resources

The foundation. Server reads full player state from DB at
`CharacterSpawn` and owns HP/MP/Stamina/regen.

**DB schema.** `0001_init.sql` already has `pos_x/y/z/yaw/zone/name/
race/class/level`. Add columns for stats and resources:
- `strength / agility / intelligence / wisdom / constitution /
  charisma / dexterity` — i32 each
- `hp / max_hp / mp / max_mp / stamina / max_stamina` — f32 each
- `xp / xp_to_next` — i32 each
- Eight slots × weapon skill columns? Or normalize into a
  per-character `skills` JSON column? Discuss in open question 1.

`CharacterSpawn` carries all of this to `PerConnection`. Existing
`HealthUpdate` / `ManaUpdate` / `StaminaUpdate` fan-outs from Track
4 already work; the *source* of those values flips from "cached
last received from client" to "server-owned, mutated by tick
phases."

**Regen tick phase.** New `tick.rs` step (alongside the existing
move / attack / AI phases). Each `PerConnection`:
- HP regen: rate scales with seated state, food/drink buffs (Track
  6 needs to track buff state server-side too — see sub-task 4),
  CON modifier.
- MP regen: ditto, plus meditation multiplier.
- Stamina regen: ditto.
- Per-second cadence — don't tick at 20 Hz; accumulate into a
  per-connection regen-accumulator and apply when ≥ 1 unit lands.

**Resource-update fan-out becomes server-driven.** Today the client
fires `ClientWorldMsg::ResourceUpdate` and the server caches +
relays. Track 6: the server *generates* `HealthUpdate` /
`ManaUpdate` / `StaminaUpdate` on its own clock (e.g., every 500 ms
or on >5% delta), no client send needed. Open question: keep the
client-→-server `ResourceUpdate` as a no-op for backward compat or
remove? Discuss in open question 2.

**Client cache.** `PlayerStats` becomes a write-once-on-spawn,
mutate-only-via-Net cache in launcher mode. Local `set_hp` etc.
become no-ops or route through `Net.send_*` (no such intents
exist yet — added incrementally as needed).

### Sub-task 2 — Server-authoritative damage formula

Port `Combat.calc_damage` to Rust. New crate or module
`crates/projectdawn-server/src/world/combat.rs`:
- STR bonus: `(strength - 50) / 10.0` applied to weapon damage
  (mirror of `Combat.STR_DAMAGE_BONUS`).
- DEX bonus for ranged: same shape, ranged weapons read DEX
  instead of STR.
- Weapon damage_min/max from item DB (which doesn't exist yet on
  the server — open question 3).
- Crit roll: DEX-based for physical (0–30%), INT-based for spell
  (0–20%), multiplier 1.5–2.0×.
- Skill multipliers: weapon skill / armor skill / casting
  discipline. Server reads from DB-loaded skill levels.

`ClientWorldMsg::Attack` shape change: drop `amount` and `crit`
fields (server computes both); keep `target_id` and `dmg_type`.
Bumps `WORLD_PROTOCOL_ID`. Server resolves and broadcasts the
existing `Hit` / `Miss` / `Evade` ServerWorldMsg variants
unchanged.

**Client predictive computation.** `Combat.calc_damage` stays as a
predictive helper for the local floating number (so the UI doesn't
wait 50 ms for server round-trip). The actual HP change is driven
by `HealthUpdate` from the server; floating number reconciles if
the server's authoritative amount differed.

### Sub-task 3 — PvP HP application

Today `Combat._apply_damage_to_node` routes RemotePlayer targets
through `broadcast_hit` (visual-only). Track 6 changes this to
route through a new `Attack` intent against the target's char_id
(player ids and enemy ids share the EntityId space, so the existing
attack intent shape works once sub-task 2 is in place).

Server's attack-apply phase (already in `tick.rs` step 4h for
enemy targets) gains a parallel branch for player targets:
- Look up target's PerConnection by char_id.
- Compute damage via the server-side formula (sub-task 2).
- Apply HP delta to target's PerConnection.
- Broadcast `Hit` to in_world peers, `HealthUpdate` to drive
  target frames.
- If target HP ≤ 0, transition to dead state, broadcast
  `EntityDied { id }`, schedule respawn (server-driven, no
  client `DeathBroadcast` needed — Track 4's variant becomes
  legacy or stays for client-initiated suicide / fall damage).

**PvP gating.** Two players can't damage each other unless flagged
PvP. The flagging system is unbuilt; either ship Track 6 with a
"PvP arena zone" hardcode (zone path → PvP allowed), or wire a
proper `/pvp on` toggle. See open question 4.

### Sub-task 4 — Server-authoritative buffs + regen rates

Today buffs live in `autoloads/buff_manager.gd`. The server caches
the snapshot (Track 4 sub-task 3) but does nothing with it.

For sub-task 1's regen tick to be correct, the server needs to know:
- Is the player seated? (Sit/Stand intent — new `ClientWorldMsg`
  variants.)
- Are food/drink buffs active? (HP regen +N / MP regen +N until
  duration expires.)
- Is meditation active? (MP regen multiplier.)

Either:
(a) **Client sends buff intents.** "Add food buff for 180s with +4
    HP regen." Server tracks duration, applies regen rate, expires.
    Cheaty (client claims any buff it wants) but easy.
(b) **Server-authoritative buff application.** Server knows item DB,
    looks up Journeybread → 4 HP regen / 180s, applies. Bigger lift
    but closes another trust gap.

Track 6 sub-task 4 lands (a) as a stepping stone. (b) is a future
track once the item DB is server-side.

### Sub-task 5 — Group XP via renet

`GroupManager.distribute_kill_xp(base_xp)` on the legacy enet path
currently splits XP among group members with a 20% bonus. Track 5
sub-task 5 awarded XP to the solo top damager only.

Track 6:
- Server needs a `GroupManager` of its own: `HashMap<GroupId,
  Vec<ClientId>>`. Wire variants: `GroupInvite`, `GroupAccept`,
  `GroupLeave`, `GroupKick` — these already exist in
  `ClientWorldMsg` as stubs. Server-side handlers needed.
- On enemy death, server iterates the killer's group (if any) and
  splits XP across all members with a +20% group bonus, sending an
  `XpGained` to each.
- Legacy enet `GroupManager` becomes a Test-Room-only path.

Once this lands, the To-Do list item "Incoming /tell RPC" becomes
the next natural step — server-side group state + tells round out
the social layer.

---

## Verification plan summary

End of Track 6, all of these should be true:

- [ ] `cargo test --release` 30+/30+ (add per-sub-task integration
      tests).
- [ ] PlayerStats in launcher mode is server-driven: editing the
      .tres save file with HP=99999 doesn't make the character
      unkillable.
- [ ] Two clients duel (under whatever PvP flag system ships):
      hits actually deduct HP; deaths fire server-driven respawn.
- [ ] Damage numbers match server's authoritative computation
      (within a 1-tick window for predictive variance).
- [ ] HP/MP/Stamina regen ticks correctly when seated, with
      food/drink buff stacking.
- [ ] Group of two killing an enemy split the XP correctly (each
      gets ~60% of base = 1.2× base total, the 20% bonus).
- [ ] No new GDScript warnings introduced.
- [ ] No new clippy warnings on server.

**Commits expected:** ~15–20 across 3 repos. Sub-task 1 is the
biggest — DB schema migration + PerConnection extension + regen
tick + PlayerStats wiring. Sub-tasks 2–3 are paired (formula port
+ PvP application).

---

## Hard rules (carry forward, do not relax)

### Project_Dawn — files you must NOT modify

- `CLAUDE.md`
- `addons/procedural_dungeon/` (embedded copy)
- `scripts/enemy.gd` (use `scripts/remote_enemy.gd` for launcher-
  mode rendering — Track 5 already separated these)
- `docs/concepts/world/maps/`
- `docs/reference/`
- `docs/playtest_notes/testing_notes_2026_05_02.md`
- `docs/playtest_notes/testing_notes_2026_05_05.md`
- `docs/playtest_notes/testing_notes_2026_05_06.md`

### Cross-repo invariants

- `scripts/net/protocol.gd` MUST stay 1:1 between Project_Dawn
  and launcher.
- The Rust `protocol` crate is canonical. `WORLD_PROTOCOL_ID`
  bumps once for the Track 6 batch (`PD_W0004 → PD_W0005`).
- `PROJECTDAWN_NETCODE_KEY` is sacred. Never logged, committed,
  or in test fixtures.
- The `gdext_net.dll` is gitignored. Track 6 rebuilds it once
  per sub-task that adds signals; don't commit the binary.
- **Re-export the game** after any GDScript / scene / DLL change
  before multi-instance testing.

### Process

- Match commit-message tone per repo. `git log --oneline -5`
  before writing one. HEREDOC body, blank line, Co-Authored-By
  footer.
- One commit per repo per logical change. Don't bundle the
  five sub-tasks.
- Pause and ask before any destructive git operation, before
  pushing to a remote, before touching files outside the agreed
  scope.
- User runs Windows / PowerShell. Use the Bash tool for POSIX
  scripts, PowerShell tool for native Windows ops.
- Session notes after the session: write
  `docs/session_notes/session_YYYY_MM_DD.md`; update
  `docs/session_notes/README.md` index.
- User wants terse responses; no end-of-task recaps. Brief
  progress updates fine.

### Build / test workflow

- Server: `cd F:/Projects/server; cargo test --release`. Should
  be 28/28 at handoff start (27 from Track 5 + the kill credit
  assertion in `player_attack_kills_enemy_and_corpse_despawns`).
- Server runtime: `cargo run -p projectdawn-server --release
  2>&1 | Tee-Object -FilePath server.log`. User runs this; you
  read the log.
- GDExtension rebuild: `cd F:/Projects/server; $env:RUSTFLAGS =
  "-C target-feature=+crt-static"; cargo build -p gdext-net
  --release`. Copy `target/release/gdext_net.dll` to
  `F:/Projects/Project_Dawn/addons/gdext_net/gdext_net.dll`.
- Game export: Project → Export → Windows Desktop preset →
  Export Project. **Re-export between client-code changes and
  multi-instance testing.**

---

## Open questions to ask the user before writing code

1. **Stats schema in DB.** Add seven int columns + six float
   columns + xp/xp_to_next directly to the characters table, OR
   normalize into per-character JSON / a join table? Recommend
   flat columns — fast SELECT, no parse cost on spawn, alters
   are cheap with SQLite. The skills table (10+ weapon/armor/
   casting skills) is the only candidate for normalization
   because the schema can grow.

2. **`ClientWorldMsg::ResourceUpdate` after authority flips.**
   Today this is the client telling the server "my HP is now N."
   Once the server owns HP, options:
   (a) Remove the variant entirely (breaking change, but it's
       Track-6-only consumers that send it).
   (b) Keep it as a *request* the server can validate or reject
       — useful if the client wants to fire a heal predictively.
   (c) Repurpose for client-side prediction reconciliation
       (server sends authoritative state, client sends what it
       thinks its state is, server re-broadcasts the diff).
   Recommend (a): clean break, predictive reconciliation lives
   client-side without a wire roundtrip.

3. **Item DB on server.** Damage formula needs weapon
   damage_min/max. Two options:
   (a) Embed an items.toml at server build time (mirror of the
       per-character .tres files in the client).
   (b) Wire-level: client sends `equipped_weapon_id` with each
       Attack; server has a lookup table.
   Recommend (a) — same shape as `data/zone_camps.toml` from
   Track 5. Inventory becomes server-authoritative as a follow-
   up track once the item DB is in place.

4. **PvP flagging.** Track 6 needs *some* answer for "can A
   attack B?" — options:
   (a) Hardcoded PvP zones (zone path → bool).
   (b) `/pvp on` toggle persisted in DB; both sides need to be
       flagged.
   (c) Always-off until a future track; ship Track 6 with PvP
       application wired but unreachable through gameplay
       (verify via test panel only).
   Recommend (c) — Track 6 closes the *technical* gap; the
   *design* of PvP rules is a separate decision documented
   in `docs/concepts/alignment/events.md` and warrants its
   own design pass.

5. **Server-side group state.** `GroupManager` lives on Godot's
   enet MultiplayerAPI. Migrating to renet is sub-task 5. Open
   questions:
   - Group invite acceptance flow: server-mediated (A sends
     GroupInvite → server forwards to B → B sends GroupAccept →
     server adds to group) vs client-mediated (A and B both
     send a "join group X" intent with the same group_id).
     Recommend server-mediated; matches the auth/character
     create handshake shape.
   - Group persistence across logout: ephemeral (groups dissolve
     when any member disconnects) vs persistent (members rejoin
     on login). Recommend ephemeral — simpler, matches typical
     MMO behavior.

6. **Regen authority and the sit/stand intent.** Today the
   client knows it's seated via `player.gd._sitting`. Server
   needs to know too. New `ClientWorldMsg::Sit` / `Stand`
   intents OR repurpose the existing `Sit` / `Stand` stubs
   (they exist as no-ops in `ClientWorldMsg`).

7. **Test panel access.** Track 4 sub-task 4 added Hit/Miss/
   Evade buttons. Track 6 likely wants a Damage Self / Heal Self
   / Apply Buff button that routes through Net so we can verify
   server-driven HP without needing PvP combat to be wired.

8. **Server live during the session.** Sub-tasks 1–5 all need
   the server running. Same Tee-Object workflow as Track 5.

---

## Quick reference — key files & autoloads

### Project_Dawn (game client)

- `autoloads/net.gd` — likely add `world_resource_update_request`
  / send-side wrappers if open question 2 leans (b) or (c).
- `autoloads/player_stats.gd` — gate setters in launcher mode;
  resources mutated only by Net handlers receiving server
  updates.
- `autoloads/combat.gd` — change `_apply_damage_to_node`'s
  RemotePlayer branch from `broadcast_hit` (visual) to a true
  Attack intent against the player's char_id.
- `autoloads/regen.gd` — early-return in launcher mode (server
  owns regen now).
- `autoloads/buff_manager.gd` — buffs become server-driven; the
  existing snapshot broadcast becomes diagnostic only.
- `autoloads/group_manager.gd` — migrate `distribute_kill_xp` and
  invite flow to Net intents.

### Server

- `crates/protocol/src/world.rs` — likely additions:
  `ClientWorldMsg::Attack` shape change (drop `amount` and
  `crit`), new sit/stand intents if not reusing existing stubs,
  group state intents (already exist as stubs). Bump
  `WORLD_PROTOCOL_ID` to PD_W0005.
- `crates/projectdawn-server/src/db.rs` — extend
  `CharacterSpawn` with stats / resources / skills; add a
  migration `0002_player_stats.sql`.
- `crates/projectdawn-server/src/world/connection.rs` —
  PerConnection gains stats, regen accumulators, sit state.
- `crates/projectdawn-server/src/world/combat.rs` (new) — ported
  damage formula from `Combat.calc_damage`.
- `crates/projectdawn-server/src/world/tick.rs` — regen tick
  phase, PvP-Hit application branch in step 4h alongside enemy
  attacks, server-side death detection for players.
- `crates/projectdawn-server/src/world/group.rs` (new) — group
  roster + XP distribution + invite handshake.
- `crates/projectdawn-server/data/items.toml` (new, if open
  question 3 → (a)) — weapon damage_min/max table.
- `crates/projectdawn-server/tests/` — at least one integration
  test per sub-task. Sub-task 3 (PvP) and sub-task 5 (group XP)
  need two-client tests.

### Launcher

- `scripts/net/protocol.gd` — mirror any new tag constants from
  the world protocol.gd.

### Procedural dungeon

No changes expected.

---

## Begin by

1. Read the 10 files in the "Read these in order" section.
2. Run `git -C <each repo> log --oneline -5` to confirm state
   matches the table at the top.
3. Read the open questions and ask the user. Questions 1
   (stats schema), 2 (ResourceUpdate fate), 3 (item DB), 4
   (PvP flagging), 5 (group state) all change the architecture.
   Get answers before sub-task 1's protocol commit lands.
4. Confirm the server is running and `cargo test --release` is
   28/28 green.
5. Implement sub-task by sub-task. After each, run its
   verification (cargo test + manual two-instance check).
6. After the session, write
   `docs/session_notes/session_YYYY_MM_DD.md` and update the
   index.

**Do not start writing code until the user has answered the open
questions specific to the sub-task you start with.** Sub-task 1
locks in the DB schema and authority flip — getting it wrong
means rewriting later sub-tasks.

When Track 6 closes, the netcode is "alpha-complete" for an MMO
core loop: server-authoritative position, identity, stats, HP,
combat, regen, enemies, loot, XP, groups. Remaining tracks beyond
this are zone partitioning / AOI (scaling), auction / social
(content), and any further trust-model lifts (server-authoritative
inventory, server-authoritative item DB).

Write `handoff_track_7.md` when Track 6 closes — the AOI / zone
partitioning track, which is the last big architectural piece
before the netcode can host hundreds of concurrent clients.
