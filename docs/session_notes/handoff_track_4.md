# Track 4 Handoff — Player state replication

You're picking up Project Dawn — a Godot 4.4 / GDScript MMORPG
client, its companion Rust server (auth WebSocket + world UDP), a
Godot launcher, and a standalone procedural dungeon generator that
will be folded into the game later. Four repos, four branches; the
table below shows state at handoff.

Tracks 1, 2, and 3 closed the server-authoritative loop for
**movement and identity**: two `.exe` instances connected to the same
server now see each other walk around in `world.tscn`. Position
broadcasts fan out at 20 Hz; EntitySpawn / EntityDespawn arrive on
the reliable system channel; remote players render via
`scenes/remote_player.tscn` with 100 ms snapshot interpolation.

**Track 4 is player state replication.** Today, when one player hits
the other, only the attacker sees the damage land. HP bars, MP bars,
stamina, buffs, cast bars, hit/miss text, deaths — all of it lives
client-local on each instance. The wire-format slots are already
defined in `protocol/src/world.rs` (`Hit`, `Miss`, `Evade`,
`HealthUpdate`, `ManaUpdate`, `StaminaUpdate`, `CastStart`,
`CastComplete`, `CastFail`, `BuffApplied`, `BuffRemoved`, `HotTick`,
`DotTick`, `EntityDied`, `XpGained`, `LevelUp`) — Track 4 wires the
fan-out and the rendering.

**Deliberate scoping choice — the trust model.** Track 4 keeps
combat math client-local. The local player remains the authority
on their own HP/MP, their own crit rolls, their own miss results.
The server is a fan-out relay: it accepts state-change messages
from the client that owns the entity and broadcasts them to peers.
This is cheaty (a malicious client could lie about their HP) but
appropriate for early alpha — the *visibility* infrastructure
needs to land before *authority* makes sense to lift.

Server-authoritative combat is **Track 6** (or later); server-
authoritative enemies are **Track 5**. When Track 5 lands, the
server will own mob state including mob-dealt damage to players,
so for mob fights the server *will* be authority. Track 4 leaves
that boundary clean by routing all damage events through the same
ServerWorldMsg variants — the only thing that changes in Track 5/6
is who computes the values.

After Track 4, two `.exe` instances will:
- Show each other's HP / MP / stamina bars filling and depleting.
- Render a cast bar over the remote player while they cast.
- Render buff icons over the remote player's nameplate.
- See "MISS" / floating damage numbers when one hits the other.
- Play a death animation when one of them dies and re-appear at
  respawn.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `c0b1c4e` (Session notes: 2026-05-11 — Track 3 multi-player replication) |
| Server | `F:\Projects\server\` | `main` | `fb95bbb` (world: fan out EntitySpawn / Position / EntityDespawn to ready peers) |
| Launcher | `F:\Projects\launcher\` | `main` | `d2f8a4e` (protocol.gd: add SW_ENTITY_SPAWN tag (mirror)) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS into DEBUG_TORCH_LABELS / DEBUG_COMPASS) |

Run `git -C <each> log --oneline -5` before touching anything to
confirm the state still matches.

## Read these in order

1. `F:\Projects\Project_Dawn\CLAUDE.md` — project conventions,
   autoload map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_11.md`
   — Track 3 close. The fan-out lifecycle (Connect → EntitySpawn,
   ClientDisconnected → EntityDespawn, step 6 → Position fan-out)
   is the pattern Track 4 extends to combat events. The
   lobby-vs-world scene bug at the end has a relevant lesson:
   anything that depends on rendering into `world.tscn` needs to
   survive scene transitions, since EntitySpawn-style reliable
   messages can arrive while the local client is still in the
   lobby.
3. `F:\Projects\server\crates\protocol\src\world.rs` — read the
   full `ServerWorldMsg` enum. Track 4 wires the combat-related
   variants (`Hit`, `Miss`, `Evade`, `HealthUpdate`, etc.) that
   already exist; you may add one or two new `ClientWorldMsg`
   variants if a clean upstream event doesn't already exist
   (`ResourceUpdate` is the likely one). Any `ClientWorldMsg`
   addition bumps `WORLD_PROTOCOL_ID` (PD_W0002 → PD_W0003).
4. `F:\Projects\Project_Dawn\autoloads\combat.gd` (395 lines) —
   client-side combat. Hit/miss/damage routing for both melee and
   spell paths. `deal_damage_to_target`, `deal_spell_damage`,
   `receive_player_damage`, `_on_auto_attack`. Existing signals
   `player_hit_enemy`, `player_took_damage`, etc. are the hook
   points for outbound broadcasts.
5. `F:\Projects\Project_Dawn\autoloads\spells.gd` (415 lines) —
   client-side casting. `cast_spell`, `_apply_spell`, signals
   `casting_started`, `spell_cast`, `spell_failed`. The cast bar
   is driven by `casting_started` already; Track 4 broadcasts
   `CastStart` at the same point.
6. `F:\Projects\Project_Dawn\autoloads\buff_manager.gd` (389
   lines) — client-side buff state. Many `add_*` entry points
   (`add_hot`, `add_dot`, `add_absorb`, `add_speed_buff`,
   `add_haste_buff`, `add_primary_stat_buff`, etc.). The
   `buffs_changed` signal fires whenever the buff set mutates.
   Decide whether to broadcast each individual add or use the
   coarser signal — see open question 2.
7. `F:\Projects\Project_Dawn\autoloads\player_death.gd` (54
   lines) — death routing. `_respawn()` either travels to bind
   point or to `_respawn_position`. Track 4 broadcasts
   `EntityDied` at the death event and lets EntitySpawn re-fire
   handle respawn visibility.
8. `F:\Projects\Project_Dawn\autoloads\regen.gd` (86 lines) — the
   HP/MP/stamina tick. Sit-to-med multipliers, food/drink stacking.
   Resource broadcasts hook off the regen tick on the local-owner
   side.
9. `F:\Projects\Project_Dawn\autoloads\damage_numbers.gd` (48
   lines) — floating combat text. Already wired for local hits;
   Track 4 reuses the same API when peer hits arrive.
10. `F:\Projects\Project_Dawn\autoloads\remote_player_manager.gd`
    — the Track 3 manager. Track 4 extends `_spawn_data` with
    last-known resource / buff / cast state so rehydration on
    scene change carries those forward too.
11. `F:\Projects\Project_Dawn\scripts\remote_player.gd` — the
    Track 3 visual stand-in. Track 4 adds child nodes for HP bar,
    MP bar, optional stamina bar, buff icon row, cast bar. All
    billboarded above the capsule.
12. `F:\Projects\Project_Dawn\autoloads\net.gd` — coarse network
    signal layer. Track 4 adds a handful of `world_*` signals
    re-emitted from the GDExtension's new typed signals.
13. `F:\Projects\server\crates\projectdawn-server\src\world\handlers.rs`
    — server-side message dispatch. Track 4 adds arms for the
    new combat-related `ClientWorldMsg` variants; each just
    fans out via helpers analogous to `send_entity_spawn`.
14. `F:\Projects\server\crates\projectdawn-server\src\world\tick.rs`
    — step 6 is the position fan-out loop; Track 4 reuses the
    same `ready_ids` slice for combat-event fan-out (or just lets
    the handler functions accept the connections map).
15. `F:\Projects\server\crates\gdext-net\src\lib.rs` — `#[signal]`
    declarations for `hit`, `miss`, `health_update`,
    `cast_start`, `buff_applied`, etc.; classify + fire arms.

---

## Current reality (as of Track 3 close, 2026-05-11)

### What works end-to-end (two players)

- **Auth WS / world UDP** — full handshake including
  `RequestWorldToken` → renet 2.0 Secure-mode `ConnectToken` →
  app-layer `Connect` / `ConnectOk`.
- **Movement** — server-authoritative position, 20 Hz, integrate
  once per tick, stale-input guard at 500 ms, fan-out to every
  ready peer including self.
- **Identity replication** — EntitySpawn carries name/race/class/
  level/pos/yaw on the reliable system channel at app-Connect
  time; EntityDespawn on disconnect; persistent `_spawn_data` on
  the manager survives lobby → world transitions.
- **Visual remote player** — capsule + billboarded nameplate +
  snapshot interpolation rendering at `now − 100 ms`.

### What's missing for combat-adjacent replication

- **No resource updates on the wire.** `HealthUpdate` /
  `ManaUpdate` / `StaminaUpdate` are defined in `ServerWorldMsg`
  but never emitted. Player HP changes locally; peers can't see
  it. There's no corresponding ClientWorldMsg variant for
  "broadcast my resources" — Track 4 adds it.
- **No cast events on the wire.** `CastStart` / `CastComplete` /
  `CastFail` defined but unused. `spells.gd._do_cast` runs entirely
  client-local; the local cast bar is driven by `casting_started`,
  peers see nothing.
- **No buff events.** `BuffApplied` / `BuffRemoved` / `HotTick` /
  `DotTick` defined but unused.
- **No hit events.** `Hit` / `Miss` / `Evade` / `EntityDied`
  defined but unused. `Combat.deal_damage_to_target` etc. run
  client-local; the damage number appears locally; the attacker's
  combat log gets a line; the *target* on a peer never receives
  anything if the target is another player.
- **No XP / level events.** `XpGained` / `LevelUp` defined but
  unused. Group XP sharing exists (`GroupManager.distribute_kill_xp`)
  but it's enet-multiplayer (legacy) — needs to ride the new
  channel when Track 4 lands.
- **Remote player scene has no resource bars.** `remote_player.tscn`
  is just a capsule + Label3D. Track 4 adds HpBar (TextureProgressBar
  or a Sprite3D-based bar), MpBar, optional StaminaBar, BuffRow
  (HBoxContainer with buff icons), CastBar (appears only during
  active cast).

### Hard layout invariants you must preserve

- `F:\Projects\Project_Dawn\scripts\net\protocol.gd` is **1:1**
  with `F:\Projects\launcher\scripts\net\protocol.gd`. Any new
  tag constants (SW_HIT, SW_HEALTH_UPDATE, etc.) get mirrored to
  both copies in the same session. The launcher doesn't decode
  them but the mirror invariant prevents drift.
- `addons/gdext_net/gdext_net.dll` is gitignored. Rebuild via
  `cargo build -p gdext-net --release` + Copy-Item (or
  `addons/gdext_net/build.ps1` once the em-dash encoding issue is
  fixed — see Track 3 deferred list).
- The Rust `protocol` crate is the source of truth for the wire
  format. `WORLD_PROTOCOL_ID` increments on any variant
  add/remove/reorder. Track 4 adds at least `ResourceUpdate` to
  `ClientWorldMsg` ⇒ bump to PD_W0003.
- `PROJECTDAWN_NETCODE_KEY` must NEVER appear in any commit, log
  line, error message, or test fixture.
- **WORLD_PROTOCOL_ID enforcement gap** — Track 3 surfaced that
  the constant is checked server-side only (the client just
  relays an opaque ConnectToken). Means stale `.exe` builds still
  connect against a newer server, but with the old GDScript →
  they appear to work and then silently no-op. Re-export after
  any Track 4 GDScript change. A future track could add a
  client-side version probe; not in Track 4 scope.

---

## Track 4 scope

Five sub-tasks. Suggested order; each is its own commit pair (or
two). One commit per logical change per repo. Whole track is
probably one full session — combat events all follow the same
"client sends → server fans out → peers render" pattern, so once
sub-task 1 lands the rest are mechanical.

### Sub-task 1 — Resource bar replication (HP / MP / stamina)

The foundation. Wires up the new ClientWorldMsg variant and the
fan-out path that the rest of the sub-tasks copy.

**Architecture decision: the owning client broadcasts.** The
local player computes resource changes (damage taken, regen ticks,
food/drink, etc.) as it does today. After any change, it sends a
new `ClientWorldMsg::ResourceUpdate { hp, max_hp, mp, max_mp,
stamina, max_stamina }` message. The server's handler expands
into three `ServerWorldMsg` broadcasts (`HealthUpdate`,
`ManaUpdate`, `StaminaUpdate`) sent to every other ready peer
(skip self — the owner already has the values).

**Throttling.** Don't broadcast on every regen tick; the regen
loop runs at 1 Hz but the values can move a lot in one tick after
a hit. Sample design: broadcast when the value changes by >5% of
max OR at most every 250 ms. Use a per-resource accumulator on
`PlayerStats` (or a new small autoload `NetCombatBroadcaster`).
Tune by ear once it's running.

**Files to touch.**

- `crates/protocol/src/world.rs` — add `ResourceUpdate { hp,
  max_hp, mp, max_mp, stamina, max_stamina }` to `ClientWorldMsg`.
  Bump `WORLD_PROTOCOL_ID` (PD_W0002 → PD_W0003).
- `crates/projectdawn-server/src/world/handlers.rs` — new arm in
  `handle_message` that expands ResourceUpdate into three
  broadcasts. Helper `fn send_resource_updates(server, conn,
  ready_ids, hp, max_hp, mp, max_mp, stamina, max_stamina)` that
  encodes once per variant, clones bytes per recipient (same
  pattern as Track 3's `build_position_msg` fan-out).
- `crates/projectdawn-server/src/world/connection.rs` — cache
  last-broadcast values on `PerConnection` so a new client
  joining gets the current resources as part of EntitySpawn
  (or via an immediate ResourceUpdate fan-out to the new client
  in step 4a). Probably easier as a follow-up broadcast in step
  4a rather than enlarging EntitySpawn — the resource fields are
  fast-moving and EntitySpawn should stay identity-only.
- `crates/gdext-net/src/lib.rs` — three new `#[signal]`s
  (`health_update`, `mana_update`, `stamina_update`); typed
  Incoming variants + classify + fire arms.
- `F:\Projects\Project_Dawn\autoloads\net.gd` — re-emit as
  `world_health_update`, etc.
- `F:\Projects\Project_Dawn\scenes\remote_player.tscn` — add HpBar
  (Sprite3D or world-space TextureProgressBar), MpBar, optional
  StaminaBar. Placement: stacked above the existing NameLabel,
  billboarded to face the camera. ~40 px tall each, 100 px wide,
  positioned around y=2.5–2.8.
- `F:\Projects\Project_Dawn\scripts\remote_player.gd` — handler
  for resource updates; updates bar fill ratios.
- `F:\Projects\Project_Dawn\autoloads\remote_player_manager.gd`
  — listen to `Net.world_health_update` / `_mana_update` /
  `_stamina_update`. Cache in `_spawn_data[id]` (so rehydration
  on scene change preserves bar state). Dispatch to live node
  via `rp.apply_resource_update(...)`.
- `F:\Projects\Project_Dawn\autoloads\player_stats.gd` — emit
  outbound `ResourceUpdate` when resources change. Hook through
  the existing `hp_changed` / `mp_changed` / etc. signals; gate
  on `Net.is_app_ready()` so local-save mode stays unaffected.

**Verification.**

1. `cargo test --release` — existing 7/7 still passing. Existing
   `world_two_clients.rs` doesn't exercise ResourceUpdate; add a
   8th assertion or a new short test.
2. Manual two-instance: hit your own /killme bind (or just stand
   in a fire DoT). Peer's view of your HP bar should drop and
   recover within 250 ms of the local change.
3. Server log clean — no errors, no rejected messages.

### Sub-task 2 — Cast bar replication

Wire `CastStart` / `CastComplete` / `CastFail`. When the local
player starts casting, all peers see a cast bar above them.

**Architecture decision.** Like sub-task 1, the owning client
broadcasts. `Spells.cast_spell()` already fires
`casting_started(spell)`; hook there to send a new
`ClientWorldMsg::CastStartBroadcast { spell_id, duration }`. On
completion, send `CastCompleteBroadcast { spell_id }`. On
interrupt or fail, send `CastFailBroadcast { reason }`. Server
relays as the existing `CastStart` / `CastComplete` / `CastFail`
ServerWorldMsg variants.

Note: `spell_id` doesn't exist today — spells are referenced by
name (`SpellData.name`). Either add a numeric id table (matches
the Rust enum better) or change ServerWorldMsg to carry the name
string. Simplest for now: keep the wire as u32 spell_id but
synthesize it from `hash(spell.name)` on both sides. Discuss in
open questions.

**Files to touch.**

- `crates/protocol/src/world.rs` — three new ClientWorldMsg
  variants (`CastStartBroadcast`, `CastCompleteBroadcast`,
  `CastFailBroadcast`). Bumps PROTOCOL_ID again (probably batch
  with sub-task 1's bump).
- handlers.rs — fan-out arms.
- gdext-net — typed signals + classify + fire.
- net.gd — re-emit.
- `remote_player.tscn` — add CastBar (hidden by default).
- `remote_player.gd` — `on_cast_start(spell_name, duration)`
  shows the bar with countdown; `on_cast_complete` hides it.
- `spells.gd` — outbound broadcast on `casting_started`, etc.

### Sub-task 3 — Buff icon replication

Wire `BuffApplied` / `BuffRemoved`. Peers see your buff icons.

**Architecture decision.** `BuffManager` has many `add_*` paths.
Don't broadcast each individual one — too chatty. Instead, on
`buffs_changed`, broadcast a snapshot: `BuffSnapshot { buffs:
Vec<(name, duration_remaining)> }` (new ClientWorldMsg). Server
relays as `BuffSnapshot` (new ServerWorldMsg — the existing
`BuffApplied` / `BuffRemoved` are awkward for full-state sync).

Trade-off: bigger per-broadcast payload, much simpler logic. At
~10 buffs × ~30 bytes per entry = 300 bytes, every time buffs
change. Acceptable.

Alternative: ride the existing `BuffApplied` / `BuffRemoved`
variants and broadcast deltas. More wire-efficient but harder to
debug (peer can end up with desynced buff state if any message
drops). Reliable channel makes drops unlikely; revisit if payload
size matters.

**Files to touch.** Similar shape to sub-task 2 plus icon table.
Buff icons are sourced from SpellData/SkillData; remote player
needs to look them up by name to render. Easier to inline a tiny
"name → texture path" table on `BuffManager` for the icon lookups
(or have remote_player.gd ask SpellDefinitions directly).

### Sub-task 4 — Hit / Miss / Evade floating text

When you hit a peer or get hit, the peer sees a floating damage
number / "MISS" / "EVADE" text appear over their head.

**Architecture decision.** The *attacker* knows the outcome
(damage amount, hit/miss/crit). The attacker broadcasts on
`combat.deal_damage_to_target` (and the spell-damage equivalents)
when the target is another player. New ClientWorldMsg variants:

```rust
HitBroadcast { target: EntityId, amount: i32, crit: bool, dmg_type: DamageType }
MissBroadcast { target: EntityId }
EvadeBroadcast { target: EntityId }
```

Server validates the attacker is `ready` (anti-spam basic), relays
as existing `Hit` / `Miss` / `Evade` ServerWorldMsg.

The target *also* needs to update their local HP — but that's
handled by sub-task 1's ResourceUpdate broadcast from the target's
own client when they take damage. Don't try to drive target HP
from the attacker's broadcast; it tangles authority and creates
race conditions during double-hits.

**Files to touch.**

- protocol/handlers/gdext-net/net.gd — same shape as sub-tasks
  1–3.
- `combat.gd` — outbound broadcast in `deal_damage_to_target` /
  `deal_spell_damage` when target is a remote player (detect by
  checking if target is a `RemotePlayer` instance).
- `remote_player.gd` — receive Hit/Miss/Evade and spawn floating
  text via `DamageNumbers.spawn_*` at `global_position`.

### Sub-task 5 — Death / Respawn replication

Wire `EntityDied`. Peers see your death animation and your
respawn.

**Architecture decision.** Two events:

1. When the dying player's HP hits 0, their client sends
   `DeathBroadcast` (new). Server relays as `EntityDied { id }`.
   Peers play remote_player death animation in place.
2. On respawn (after `_respawn()` runs locally), the dying
   player's client sends a fresh `ResourceUpdate` (sub-task 1) +
   the next `Position` broadcast fan-out from the server places
   the now-alive player at the respawn point. No separate
   "Respawn" variant needed — the existing position fan-out and
   resource update cover it.

Edge case: while the player is mid-death (lying down before
respawn), peers should keep rendering the corpse. Track 4 just
plays a one-shot fall-over animation and leaves the capsule in
place until the next EntitySpawn fan-out (which doesn't happen on
respawn since there's no Connect event). Alternative: broadcast
`EntityDespawn` on death, `EntitySpawn` on respawn — keeps the
remote_player_manager logic uniform but adds a re-spawn message
the server has to either compute from a stale broadcast or
relay from the dying client. Discuss in open questions.

**Files to touch.**

- protocol/handlers/gdext-net/net.gd.
- `player_death.gd` — outbound broadcasts on death + respawn.
- `remote_player.gd` — death animation + state machine
  (alive/dead/respawning).

---

## Verification plan summary

End of Track 4, all of these should be true:

- [ ] `cargo test --release` 8+/8+ (add at least one new integration
      test for resource fan-out).
- [ ] Two `.exe` instances see each other's HP / MP / stamina bars
      update.
- [ ] Cast bar appears over the casting peer.
- [ ] Buff icons appear over a peer's nameplate when they receive
      a buff.
- [ ] Hit / Miss / Evade floating text appears over peers when
      they take damage.
- [ ] One peer dies → other peer sees death animation; respawned
      peer reappears at bind/respawn point.
- [ ] No new GDScript warnings introduced.
- [ ] No new clippy warnings on server.

**Commits expected:** ~10 across 3 repos (5 sub-tasks × ~2
commits each + protocol.gd mirrors + session notes). Don't bundle
— each sub-task gets its own commit pair so a regression can be
bisected cleanly.

---

## Hard rules (carry forward, do not relax)

### Project_Dawn — files you must NOT modify

- `CLAUDE.md`
- `addons/procedural_dungeon/` (the embedded copy)
- `scripts/enemy.gd` (user iterates on it directly between sessions)
- `docs/concepts/world/maps/`
- `docs/reference/`
- `docs/playtest_notes/testing_notes_2026_05_02.md`
- `docs/playtest_notes/testing_notes_2026_05_05.md`
- `docs/playtest_notes/testing_notes_2026_05_06.md`

### Cross-repo invariants

- `scripts/net/protocol.gd` MUST stay 1:1 between Project_Dawn
  and launcher. SHA256-equality is the contract.
- The Rust `protocol` crate is canonical. `WORLD_PROTOCOL_ID`
  bumps on any wire-format break. Track 4 bumps it once
  (sub-task 1's batch; reuse the same bump for sub-tasks 2–5 if
  they all land in one session).
- `PROJECTDAWN_NETCODE_KEY` is sacred. Never logged, committed,
  or in test fixtures.
- The `gdext_net.dll` is gitignored. Track 4 rebuilds it once
  per sub-task that adds signals; don't commit the binary.
- **Re-export the game** (`Project → Export → Windows Desktop →
  Export Project`) after any GDScript / scene / DLL change before
  multi-instance testing. The pre-Track-3 export gotcha bit us;
  the protocol-id check is server-side only, so stale builds
  still connect but silently no-op the new code paths.

### Process

- Match commit-message tone per repo. `git log --oneline -5`
  before writing one. HEREDOC body, blank line,
  Co-Authored-By footer.
- One commit per repo per logical change. Don't bundle the
  five sub-tasks.
- Pause and ask before any destructive git operation, before
  pushing to a remote, before touching files outside the agreed
  scope.
- User runs Windows / PowerShell. Use the Bash tool for POSIX
  scripts, PowerShell tool for native Windows ops. PowerShell 5.1
  quirks documented in CLAUDE.md.
- Session notes after the session: append to
  `docs/session_notes/session_YYYY_MM_DD.md`; update
  `docs/session_notes/README.md` index.
- User wants terse responses; no end-of-task recaps or change
  summaries. Brief progress updates fine.

### Build / test workflow

- Server: `cd F:/Projects/server; cargo test --release`. Should
  be 7/7 at handoff start (auth 3 + protocol 2 + world_smoke 1 +
  world_two_clients 1). Track 4 adds at least one resource-
  replication integration test.
- Server runtime: `cargo run -p projectdawn-server 2>&1 |
  Tee-Object -FilePath server.log`. User runs this; you read the
  log.
- GDExtension rebuild: `cd F:/Projects/server; $env:RUSTFLAGS =
  "-C target-feature=+crt-static"; cargo build -p gdext-net
  --release`. Output at `target/release/gdext_net.dll`. Copy to
  `addons/gdext_net/gdext_net.dll`. `build.ps1` has a PowerShell
  5.1 em-dash parser issue — pending fix from Track 3.
- Game export: Project → Export → Windows Desktop preset →
  Export Project → `builds/ProjectDawn.exe` (and `.console.exe`).
  **Re-export between client-code changes and multi-instance
  testing** — see Track 3 lesson.
- Launcher run: open `F:/Projects/launcher/project.godot` in
  Godot 4.4, F5.

---

## Open questions to ask the user before writing code

1. **Spell ID synthesis.** Today spells are referenced by name
   (`SpellData.name`), not numeric id. ServerWorldMsg::CastStart
   has `spell_id: u32`. Three options:
   (a) Add a name → u32 hash table client-side; server relays
       opaque u32 + name string.
   (b) Change ServerWorldMsg::CastStart to carry name: String
       instead of spell_id: u32 (variant change ⇒ protocol bump).
   (c) Add a SpellDefinitions table on both sides with stable
       numeric ids.
   Recommend (b) for slice — strings on the reliable channel are
   cheap, and we don't have a numeric-id table to maintain. Bump
   PROTOCOL_ID in the same batch as sub-task 1's ResourceUpdate
   addition.

2. **Buff broadcast: snapshot vs delta?** `BuffSnapshot` (whole
   buff list every time something changes) is simpler and
   harder to desync; `BuffApplied` / `BuffRemoved` (deltas) is
   more efficient but state can desync on a message drop.
   Recommend snapshot for slice — at ~10 buffs × ~30 B = 300 B
   per buff-change, payload is negligible and the reliable
   channel keeps things stable.

3. **Death scene — extra message or use existing?**
   (a) Send `DeathBroadcast` → server relays as `EntityDied`;
       peers play death anim in place; respawn happens silently
       via the next Position broadcast.
   (b) Send `DeathBroadcast` → server relays `EntityDespawn` for
       the dying player; on respawn the dying client re-sends a
       Connect-like "I'm here again" trigger; server fires a
       fresh EntitySpawn fan-out. Uniform with Track 3 spawn
       lifecycle but adds re-spawn message.
   Recommend (a) for slice — less moving parts. Peer's
   remote_player.gd handles "death → corpse" as a local state
   machine; respawn lands as a position teleport.

4. **Resource broadcast throttle.** 5% delta-of-max OR 250 ms,
   whichever first? Or a different shape? Tune by ear; just need
   a starting point.

5. **Hit / Miss / Evade visibility — when target is yourself?**
   When peer attacks you, server's relay includes the hit. Local
   client *also* has its own combat tick processing the incoming
   damage. Two ways to avoid double-rendering the floating text:
   filter by `target == own player_id` and skip (let local combat
   handle), OR have the local Hit handler use a different code
   path (since local already shows it via existing combat log
   line). Recommend filter-by-own-id-and-skip; same pattern as
   Position / EntitySpawn.

6. **XP / LevelUp — Track 4 or defer?** `XpGained` and `LevelUp`
   are defined on ServerWorldMsg but only currently fire for
   group XP sharing (legacy enet path). Replicating these to
   peers is mostly cosmetic ("Peer leveled up!" chat line). Can
   defer to a small follow-up. Recommend defer unless you have
   time at the end of the session.

7. **Server live during the session?** Sub-tasks 1–5 all need the
   server running for multi-instance verification. Same
   `Tee-Object` workflow as Track 3.

---

## Quick reference — key files & autoloads

### Project_Dawn (game client)

- `autoloads/net.gd` — Net adapter. Add `world_health_update` /
  `_mana_update` / `_stamina_update` / `_cast_start` /
  `_cast_complete` / `_cast_fail` / `_buff_snapshot` /
  `_hit` / `_miss` / `_evade` / `_entity_died` signals.
- `autoloads/remote_player_manager.gd` — extend `_spawn_data` with
  resource / buff / cast state for rehydration. Listen to the
  new Net signals; dispatch to live RemotePlayer via methods.
- `scripts/remote_player.gd` — new methods: `apply_resource_update`,
  `on_cast_start` / `_complete` / `_fail`, `apply_buff_snapshot`,
  `on_hit_event` / `_miss` / `_evade`, `play_death`.
- `scenes/remote_player.tscn` — add HpBar, MpBar, StaminaBar
  (optional), BuffRow, CastBar. All billboarded.
- `scripts/net/protocol.gd` — new SW_* tag constants. Mirror to
  launcher in same commit pair.
- `autoloads/player_stats.gd` — outbound `ResourceUpdate`
  broadcast on resource change (throttled).
- `autoloads/spells.gd` — outbound `CastStartBroadcast` /
  `CastCompleteBroadcast` / `CastFailBroadcast`.
- `autoloads/buff_manager.gd` — outbound `BuffSnapshot` on
  `buffs_changed`.
- `autoloads/combat.gd` — outbound `HitBroadcast` /
  `MissBroadcast` / `EvadeBroadcast` when target is a remote
  player.
- `autoloads/player_death.gd` — outbound `DeathBroadcast`.

### Server

- `crates/protocol/src/world.rs` — new ClientWorldMsg variants
  (`ResourceUpdate`, `CastStartBroadcast`, `CastCompleteBroadcast`,
  `CastFailBroadcast`, `BuffSnapshot`, `HitBroadcast`,
  `MissBroadcast`, `EvadeBroadcast`, `DeathBroadcast`). Possibly
  a new ServerWorldMsg::BuffSnapshot (or repurpose
  BuffApplied/Removed if you go delta route). Bump PROTOCOL_ID.
- `crates/projectdawn-server/src/world/handlers.rs` — fan-out
  helpers analogous to `send_entity_spawn`; arms in
  `handle_message` for each new ClientWorldMsg variant.
- `crates/projectdawn-server/src/world/tick.rs` — no major
  structural change; the fan-out helpers reuse `ready_ids` from
  step 6 if you batch.
- `crates/projectdawn-server/src/world/connection.rs` — cache
  last-known resource values (optional, for late-joiner sync).
- `crates/gdext-net/src/lib.rs` — typed signals for each new
  ServerWorldMsg variant; Incoming enum extended; classify + fire
  arms. The `#![allow(clippy::too_many_arguments)]` from Track 3
  covers any new wide signals.
- `crates/projectdawn-server/tests/` — at least one new
  integration test (e.g. `world_resources.rs`) asserting that
  ResourceUpdate from one client lands as `HealthUpdate` at the
  other.

### Launcher

- `scripts/net/protocol.gd` — mirror new tag constants. SHA256-
  equality with game-side copy is the contract.

### Procedural dungeon

No changes.

---

## Begin by

1. Read the 15 files in the "Read these in order" section.
2. Run `git -C <each repo> log --oneline -5` to confirm state
   matches the table at the top.
3. Read the open questions and ask the user. Questions 1
   (spell_id strategy), 2 (buff snapshot vs delta), and 3 (death
   replication shape) all change the protocol additions, so
   answer them before sub-task 1's protocol commit lands.
4. Confirm the server is running. If not, restart together at
   the start of the session.
5. Implement sub-task by sub-task. After each, run its
   verification (cargo test + manual two-instance check).
   **Don't stack multiple unverified changes** — the wire
   format mistake in sub-task 1 propagates to the rest if you
   plow forward.
6. After the session, write notes in
   `docs/session_notes/session_YYYY_MM_DD.md` and update the
   index in `docs/session_notes/README.md`.

**Do not start writing code until the user has answered the open
questions specific to the sub-task you start with.** The protocol
bump is small but irreversible-feeling once committed; the buff
broadcast shape bakes assumptions into BuffManager that are
annoying to re-shape.

When Track 4 closes, write `handoff_track_5.md` for the next
session — server-authoritative enemies, the bigger of the two
remaining multiplayer pieces.
